require 'rails_helper'

RSpec.describe OrderConsolidation, type: :model do
    
    describe "create_inventory" do
        
        it "creates products with correct inventory" do
            xml_string="<FbiXml>\n<FbiMsgsRs>\n<ExecuteQueryRs>\n<Rows>\n<Row>\"HEADER ROW\"</Row>\n<Row>\"PRODUCT02\",\"11091\",\"0\",\"200\",\"12\",\"5\",\"200.0\",\"0.0\",\"0.0\"</Row>\n<Row>\"PRODUCT01\",\"11091\",\"10\",\"10\",\"3\",\"1\",\"200.0\",\"0.0\",\"0.0\"</Row>\n   </Rows>\n</ExecuteQueryRs>\n  </FbiMsgsRs>\n</FbiXml>\n"
            xml=Nokogiri::XML(xml_string)
            puts "XML: #{xml}"
            puts "XML rows: #{xml.xpath('//Row').count.inspect}"
            allow(OrderConsolidation).to receive(:get_inventory_xml_from_fishbowl).and_return(xml)
            OrderConsolidation.skip_callback(:create, :after, :create_sales_orders)
            OrderConsolidation.skip_callback(:create, :after, :consolidate_orders)
            OrderConsolidation.skip_callback(:create, :before, :create_inventory)
            oc=OrderConsolidation.create
            oc.create_inventory
            products=Product.all
            puts "Products: #{products.inspect}"
            product_1 = oc.products.find_by_num "PRODUCT01"
            product_2 = oc.products.find_by_num "PRODUCT02"
            expect(product_1.qty_pickable_from_fb).to be(6)
            expect(product_1.qty_pickable).to be(6)
            expect(product_2.qty_pickable_from_fb).to be(183)
            expect(product_2.qty_pickable).to be(183)
        end
        
        
    end
  
    describe "decrement_inventory" do
        
        it "decrements inventory and saves parent order consolidation" do
            OrderConsolidation.skip_callback(:create, :after, :create_sales_orders)
            OrderConsolidation.skip_callback(:create, :after, :consolidate_orders)
            OrderConsolidation.skip_callback(:create, :before, :create_inventory_hash)
            order_consolidation=OrderConsolidation.create
            Product.create(num: 'product_10', qty_pickable_from_fb: 10, qty_pickable: 10, order_consolidation: order_consolidation)
            order_consolidation.decrement_inventory(product_num: "product_10", qty: 2)
            expect(order_consolidation.products.find_by_num("product_10").qty_pickable).to eq(8)
        end
        
    end
    
end
