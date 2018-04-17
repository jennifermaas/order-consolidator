require 'rails_helper'

RSpec.describe SalesOrderItem, type: :model do

    describe "qty_pickable" do
        
        before :each do
            OrderConsolidation.skip_callback(:create, :after, :create_sales_orders)
            OrderConsolidation.skip_callback(:create, :after, :consolidate_orders)
            OrderConsolidation.skip_callback(:create, :after, :create_inventory)
            @product_1 = Product.create(num: '10', qty_pickable_from_fb: 10, qty_pickable: 10, order_consolidation: order_consolidation)
        end
        let(:order_consolidation) {create(:order_consolidation)}
        let(:customer) {create(:customer, order_consolidation: order_consolidation)}
        let(:sales_order) {create(:sales_order, customer: customer)}

        
        it "returns 0 when product num is not found in products for the order_consolidation" do
            sales_order_item = SalesOrderItem.new(num: '1', product_num: "11",qty_to_fulfill: 1, sales_order: sales_order)  
            expect(sales_order_item.qty_pickable).to eq(0)
        end
        
        it "returns product.qty_pickable when product num is found for the order_consolidation" do
            sales_order_item = SalesOrderItem.new(num: '1', product_num: "10",qty_to_fulfill: 10, sales_order: sales_order)  
            expect(sales_order_item.qty_pickable).to eq(10)
        end
        
    end
    
    describe "is_fully_pickable?" do
        
        before :each do 
            allow_any_instance_of(SalesOrderItem).to receive(:qty_pickable).and_return(10)
        end
       
        it "returns true when qty_to_fulfill < qty_pickable" do
            sales_order_item = SalesOrderItem.new(num: '1', product_num: "product_10",qty_to_fulfill: 1)  
            expect(sales_order_item.is_fully_pickable?).to eq(true)
        end
        it "returns true when qty_to_fulfill == qty_pickable" do
            sales_order_item = SalesOrderItem.new(num: '1', product_num: "product_10",qty_to_fulfill: 10)    
            expect(sales_order_item.is_fully_pickable?).to eq(true)
        end
        it "returns false when qty_to_fulfill > qty_pickable" do
            sales_order_item = SalesOrderItem.new(num: '1', product_num: "product_10",qty_to_fulfill: 12) 
            expect(sales_order_item.is_fully_pickable?).to eq(false)
        end
    end
    
end