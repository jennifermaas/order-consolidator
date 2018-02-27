require 'rails_helper'

RSpec.describe SalesOrder, type: :model do
    
    before :each do 
        @sales_order = SalesOrder.new(num: '123')
        @pickable_sales_order_item_1 = SalesOrderItem.new(qty_to_fulfill: 10)
        @pickable_sales_order_item_1.product = Product.new(product_num: '123', quantities: {qty_available: 10})
        @pickable_sales_order_item_2 = SalesOrderItem.new(qty_to_fulfill: 10)
        @pickable_sales_order_item_2.product = Product.new(product_num: '124', quantities: {qty_available: 10})
        @not_pickable_sales_order_item = SalesOrderItem.new(qty_to_fulfill: 10)
        @not_pickable_sales_order_item.product = Product.new(product_num: '125', quantities: {qty_available: 0})
        @partially_pickable_sales_order_item = SalesOrderItem.new(qty_to_fulfill: 10)
        @partially_pickable_sales_order_item.product = Product.new(product_num: '125', quantities: {qty_available: 2})
    end

    describe "pickability_status" do 
    
        it "returns pickable if all items are totally pickable " do
            @sales_order.sales_order_items << @pickable_sales_order_item_1
            @sales_order.sales_order_items << @pickable_sales_order_item_2
            expect(@sales_order.pickability_status).to eq('pickable')
        end
        
        it "returns mixed if there is an item that isn't totally pickable and one that is" do 
            @sales_order.sales_order_items << @pickable_sales_order_item_1
            @sales_order.sales_order_items << @not_pickable_sales_order_item
            expect(@sales_order.pickability_status).to eq('mixed')
        end
        
        it "returns mixed if there is an item that is partially pickable and one that is" do 
            @sales_order.sales_order_items << @pickable_sales_order_item_1
            @sales_order.sales_order_items << @partially_pickable_sales_order_item
            expect(@sales_order.pickability_status).to eq('mixed')
        end
        
        it "returns not pickable if there are pickable and partially pickable items" do
            @sales_order.sales_order_items << @not_pickable_sales_order_item
            @sales_order.sales_order_items << @partially_pickable_sales_order_item
            expect(@sales_order.pickability_status).to eq('not_pickable')
        end
        
        it "returns not pickable if there is only a not pickable itme" do
            @sales_order.sales_order_items << @not_pickable_sales_order_item
            @sales_order.sales_order_items << @partially_pickable_sales_order_item
            expect(@sales_order.pickability_status).to eq('not_pickable')
        end
        
        it "returns empty if the order has no items" do
             expect(@sales_order.pickability_status).to eq('empty')
        end
    
    end

    
end