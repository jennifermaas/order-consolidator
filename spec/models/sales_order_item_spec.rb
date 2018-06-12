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
    
    describe "is_inventory_item?" do
        let(:order_consolidation) {create(:order_consolidation)}
        let(:customer) {create(:customer, order_consolidation: order_consolidation)}
        let(:sales_order) {create(:sales_order, customer: customer)}
        
        it "returns true if the so_item_type_id is '12'" do
            sales_order_item = SalesOrderItem.create(so_item_type_id: "12")
            expect(sales_order_item.is_inventory_item?).to eq(true)
        end
        it "returns true if the so_item_type_id is '0'" do
            sales_order_item = SalesOrderItem.create(so_item_type_id: "0")
            expect(sales_order_item.is_inventory_item?).to eq(true)
        end
        it "returns false if the so_item_type_id is over 12" do
            sales_order_item = SalesOrderItem.create(so_item_type_id: "13")
            expect(sales_order_item.is_inventory_item?).to eq(false)
        end
        it "returns false if the so_item_type_id is 'nil'" do
            sales_order_item = SalesOrderItem.create(so_item_type_id: nil)
            expect(sales_order_item.is_inventory_item?).to eq(false)
        end
    end
    
end