require 'rails_helper'

RSpec.describe SalesOrder, type: :model do

    describe "pickability_status" do 
        let(:sales_order) { create(:sales_order, num: '123') }
        let(:product_10) {create(:product, num: 'product_10', qty_pickable: 10 )}
        let(:product_0) {create(:product, num: 'product_10', qty_pickable: 0 )}
        let(:pickable_sales_order_item_1) { create(:sales_order_item, qty_to_fulfill: 10, product: product_10 )}
        let(:pickable_sales_order_item_2) { create(:sales_order_item, qty_to_fulfill: 10, product: product_10 )}
        let(:not_pickable_sales_order_item) { create(:sales_order_item, qty_to_fulfill: 10, product: product_0 )}
        let(:partially_pickable_sales_order_item) { create(:sales_order_item, qty_to_fulfill: 12, product: product_10 )}
    
        it "returns pickable if all items are totally pickable " do
            sales_order.sales_order_items << pickable_sales_order_item_1
            sales_order.sales_order_items << pickable_sales_order_item_2
            expect(sales_order.pickability_status).to eq('pickable')
        end
        
        it "returns mixed if there is an item that isn't totally pickable and one that is" do 
            sales_order.sales_order_items << pickable_sales_order_item_1
            sales_order.sales_order_items << not_pickable_sales_order_item
            expect(sales_order.pickability_status).to eq('mixed')
        end
        
        it "returns mixed if there is an item that is partially pickable and one that is pickable" do 
            sales_order.sales_order_items << pickable_sales_order_item_1
            sales_order.sales_order_items << partially_pickable_sales_order_item
            expect(sales_order.pickability_status).to eq('mixed')
        end
        
        it "returns mixed if there are not pickable and partially pickable items" do
            sales_order.sales_order_items << not_pickable_sales_order_item
            sales_order.sales_order_items << partially_pickable_sales_order_item
            expect(sales_order.pickability_status).to eq('not_pickable')
        end
        
        it "returns not pickable if there is only a not pickable item" do
            sales_order.sales_order_items << not_pickable_sales_order_item
            expect(sales_order.pickability_status).to eq('not_pickable')
        end
        
        it "returns empty if the order has no items" do
             expect(sales_order.pickability_status).to eq('empty')
        end
    
    end

    
end