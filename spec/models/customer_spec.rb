require 'rails_helper'

RSpec.describe Customer, type: :model do

    describe "create_sales_orders" do
        
    end
    
    describe "consolidated_line_items" do
        let(:product_1) {create(:product, num: '1', qty_pickable: 10 )}
        let(:product_2) {create(:product, num: '2', qty_pickable: 10 )}
        let(:product_3) {create(:product, num: '1', qty_pickable: 10 )}
        let(:product_4) {create(:product, num: '2', qty_pickable: 10 )}
        let(:product_5) {create(:product, num: '5', qty_pickable: 10 )}
        let(:product_6) {create(:product, num: '6', qty_pickable: 10 )}
        let(:customer) {create(:customer)}
        let(:sales_order_1) {create(:sales_order, customer: customer)}
        let(:sales_order_2) {create(:sales_order, customer: customer)}
        
        it "creates a line item list where line items with matching product numbers are merged and their qty_to_fulfill are summed" do

            sales_order_1.sales_order_items << create(:sales_order_item, product: product_1, qty_to_fulfill: 10)
            sales_order_1.sales_order_items << create(:sales_order_item, product: product_2, qty_to_fulfill: 3)
            #
            sales_order_2.sales_order_items << create(:sales_order_item, product: product_3, qty_to_fulfill: 12)
            sales_order_2.sales_order_items << create(:sales_order_item, product: product_4, qty_to_fulfill: 5)
            #
            consolidated_line_items=customer.consolidated_line_items
            expect(consolidated_line_items.length).to eq(2)
            expect(consolidated_line_items.find{|x| x.product.num==1}.qty_to_fulfill).to eq(22)
            expect(consolidated_line_items.find{|x| x.product.num==2}.qty_to_fulfill).to eq(8)
        end
        
        it "creates a line item list even if all items have products with unique product numbers" do 
            sales_order_1.sales_order_items << create(:sales_order_item, product: product_1, qty_to_fulfill: 10)
            sales_order_1.sales_order_items << create(:sales_order_item, product: product_2, qty_to_fulfill: 3)
            #
            sales_order_2.sales_order_items << create(:sales_order_item, product: product_5, qty_to_fulfill: 12)
            sales_order_2.sales_order_items << create(:sales_order_item, product: product_6, qty_to_fulfill: 5)
            #
            consolidated_line_items=customer.consolidated_line_items
            expect(consolidated_line_items.length).to eq(4)
            expect(consolidated_line_items.find{|x| x.product.num==1}.qty_to_fulfill).to eq(10)
            expect(consolidated_line_items.find{|x| x.product.num==2}.qty_to_fulfill).to eq(3)
            expect(consolidated_line_items.find{|x| x.product.num==5}.qty_to_fulfill).to eq(12)
            expect(consolidated_line_items.find{|x| x.product.num==6}.qty_to_fulfill).to eq(5)
        end
        
        
        it "merges two sales order items with same product on the same order" do
            #
            sales_order_1.sales_order_items << create(:sales_order_item, product: product_1, qty_to_fulfill: 10)
            sales_order_1.sales_order_items << create(:sales_order_item, product: product_3, qty_to_fulfill: 3)
            #
            consolidated_line_items=customer.consolidated_line_items
            expect(consolidated_line_items.length).to eq(1)
            expect(consolidated_line_items.find{|x| x.product.num==1}.qty_to_fulfill).to eq(13)
        end
    end
    
        
    describe "line_items_need_consolidation?" do
        
        let(:product_1) {create(:product, num: '1', qty_pickable: 10 )}
        let(:product_2) {create(:product, num: '2', qty_pickable: 10 )}
        let(:product_3) {create(:product, num: '1', qty_pickable: 10 )}
        let(:product_4) {create(:product, num: '2', qty_pickable: 10 )}
        let(:product_5) {create(:product, num: '5', qty_pickable: 10 )}
        let(:product_6) {create(:product, num: '6', qty_pickable: 10 )}
        let(:customer) {create(:customer)}
        let(:sales_order_1) {create(:sales_order, customer: customer)}
        let(:sales_order_2) {create(:sales_order, customer: customer)}
        
        it "returns true if there is more than one line item with the same product number" do
            sales_order_1.sales_order_items << create(:sales_order_item, product: product_1, qty_to_fulfill: 10)
            sales_order_1.sales_order_items << create(:sales_order_item, product: product_2, qty_to_fulfill: 3)
            #
            sales_order_2.sales_order_items << create(:sales_order_item, product: product_3, qty_to_fulfill: 12)
            sales_order_2.sales_order_items << create(:sales_order_item, product: product_4, qty_to_fulfill: 5)
            #
            expect(customer.line_items_need_consolidation?).to eq(true)
        end
        
        it "returns true if all line items are unique" do
            sales_order_1.sales_order_items << create(:sales_order_item, product: product_1, qty_to_fulfill: 10)
            sales_order_1.sales_order_items << create(:sales_order_item, product: product_2, qty_to_fulfill: 3)
            expect(customer.line_items_need_consolidation?).to eq(false)
        end
    
    end
    
    describe "create_consolidated_orders" do
        let(:product_1) {create(:product, num: '1', qty_pickable: 10 )}
        let(:product_2) {create(:product, num: '2', qty_pickable: 10 )}
        let(:product_3) {create(:product, num: '3', qty_pickable: 0 )}
        let(:product_4) {create(:product, num: '4', qty_pickable: 10 )}
        let(:customer) {create(:customer)}
        let(:sales_order_1) {create(:sales_order, customer: customer)}
        let(:sales_order_2) {create(:sales_order, customer: customer)}
        
        it "creates a pickable order with pickable and partially pickable items and not pickable order with partially pickable items" do
            #
            sales_order_1.sales_order_items << create(:sales_order_item, product: product_1, qty_to_fulfill: 10)
            sales_order_1.sales_order_items << create(:sales_order_item, product: product_2, qty_to_fulfill: 12)
            sales_order_2.sales_order_items << create(:sales_order_item, product: product_3, qty_to_fulfill: 12)
            sales_order_2.sales_order_items << create(:sales_order_item, product: product_4, qty_to_fulfill: 5)
            #
            customer.create_consolidated_orders
            pickable_order=customer.pickable_order
            not_pickable_order=customer.not_pickable_order
            puts "CUSTOMER.orders: #{customer.sales_orders.inspect}"
            puts "sales_order_1.sales_order_items: #{sales_order_1.sales_order_items.inspect}"
            puts "sales_order_2.sales_order_items: #{sales_order_2.sales_order_items.inspect}"
            puts "PICKABLE_ORDER: #{pickable_order.inspect}"
            puts "NOT PICKABLE_ORDER: #{not_pickable_order.inspect}"
            expect(pickable_order.sales_order_items.length).to eq(3)
            expect(pickable_order.sales_order_items.find {|x| x.product.num==product_1.num}.qty_to_fulfill).to eq(10)
            expect(pickable_order.sales_order_items.find {|x| x.product.num==product_2.num}.qty_to_fulfill).to eq(10)
            expect(pickable_order.sales_order_items.find {|x| x.product.num==product_4.num}.qty_to_fulfill).to eq(5)
            expect(not_pickable_order.sales_order_items.length).to eq(2)
            expect(not_pickable_order.sales_order_items.find {|x| x.product.num==product_2.num}.qty_to_fulfill).to eq(2)
            expect(not_pickable_order.sales_order_items.find {|x| x.product.num==product_3.num}.qty_to_fulfill).to eq(12)
        end
        
    end
    
    
    describe "needs_consolidation?" do
        let(:product_10) {create(:product, num: '10', qty_pickable: 10 )}
        let(:product_12) {create(:product, num: '12', qty_pickable: 12 )}
        let(:product_0) {create(:product, num: '0', qty_pickable: 0 )}
        let(:product_00) {create(:product, num: '00', qty_pickable: 0 )}
        let(:pickable_sales_order_item) {create(:sales_order_item, qty_to_fulfill: 10, product: product_10)}
        let(:pickable_sales_order_item_2) {create(:sales_order_item, qty_to_fulfill: 10, product: product_12)}
        let(:not_pickable_sales_order_item) {create(:sales_order_item, qty_to_fulfill: 10, product: product_0)}
        let(:not_pickable_sales_order_item_2) {create(:sales_order_item, qty_to_fulfill: 10, product: product_00)}
        let(:mixed_sales_order_item) {create(:sales_order_item, qty_to_fulfill: 12, product: product_10)}
        let(:customer) {create(:customer)}
        #before :each do
        #    @sales_order = SalesOrder.new(num: '123')
        #    @pickable_sales_order_item_1 = SalesOrderItem.new(qty_to_fulfill: 10)
        #    @pickable_sales_order_item_1.product = Product.new(num: '123', quantities: {qty_available: 10})
        #    @pickable_sales_order_item_2 = SalesOrderItem.new(num: 10)
        #    @pickable_sales_order_item_2.product = Product.new(num: '124', quantities: {qty_available: 10})
        #    @not_pickable_sales_order_item = SalesOrderItem.new(qty_to_fulfill: 10)
        #    @not_pickable_sales_order_item.product = Product.new(num: '125', quantities: {qty_available: 0})
        #    @partially_pickable_sales_order_item = SalesOrderItem.new(qty_to_fulfill: 10)
        #    @partially_pickable_sales_order_item.product = Product.new(num: '126', quantities: {qty_available: 2})
        #end
        
        it "returns true when there are more than two orders" do
            customer.sales_orders << create(:sales_order)
            customer.sales_orders << create(:sales_order)
            customer.sales_orders << create(:sales_order)
            expect(customer.needs_consolidation?).to be(true)
        end
        
        it "returns true when at least one order has both a pickable and not pickable item" do
            sales_order=create(:sales_order)
            sales_order.sales_order_items << pickable_sales_order_item
            sales_order.sales_order_items << not_pickable_sales_order_item
            customer.sales_orders << sales_order
            expect(customer.needs_consolidation?).to be(true)
        end
        
        it "returns true when at lease one order has both a pickable and mixed item" do
            sales_order=create(:sales_order)
            sales_order.sales_order_items << pickable_sales_order_item
            sales_order.sales_order_items << mixed_sales_order_item
            customer.sales_orders << sales_order
            expect(customer.needs_consolidation?).to be(true)
        end
        
        it "returns true when there are at least two orders with pickable items" do
            sales_order_1=create(:sales_order)
            sales_order_1.sales_order_items << pickable_sales_order_item
            sales_order_2=create(:sales_order)
            sales_order_2.sales_order_items << pickable_sales_order_item_2
            customer.sales_orders << sales_order_1
            customer.sales_orders << sales_order_2
            expect(customer.needs_consolidation?).to be(true)
        end
        
        it "returns true when there are at least two orders with not pickable items" do
            sales_order_1=create(:sales_order)
            sales_order_1.sales_order_items << not_pickable_sales_order_item
            sales_order_2=create(:sales_order)
            sales_order_2.sales_order_items << not_pickable_sales_order_item_2
            customer.sales_orders << sales_order_1
            customer.sales_orders << sales_order_2
            expect(customer.needs_consolidation?).to be(true)
        end
        
        it "returns false when there are two orders, one with all pickable items and one with all not pickable items" do 
            sales_order_1=create(:sales_order)
            sales_order_1.sales_order_items << not_pickable_sales_order_item
            sales_order_2=create(:sales_order)
            sales_order_2.sales_order_items << pickable_sales_order_item
            customer.sales_orders << sales_order_1
            customer.sales_orders << sales_order_2
            expect(customer.needs_consolidation?).to be(false)
        end
        
        it "returns false when there is exactly one order with only pickable items" do
            sales_order_1=create(:sales_order)
            sales_order_1.sales_order_items << not_pickable_sales_order_item
            sales_order_1.sales_order_items << not_pickable_sales_order_item_2
            customer.sales_orders << sales_order_1
            puts "not_pickable_sales_order_item: #{not_pickable_sales_order_item.product.num}"
            puts "not_pickable_sales_order_item_2: #{not_pickable_sales_order_item_2.product.num}"
            puts "product_0: #{product_0.inspect}"
            puts "product_00: #{product_00.inspect}"
            expect(customer.needs_consolidation?).to be(false)
        end
        it "returns false when there is exactly one order with only not pickable items" do
            sales_order_1=create(:sales_order)
            sales_order_1.sales_order_items << pickable_sales_order_item
            sales_order_1.sales_order_items << pickable_sales_order_item_2
            customer.sales_orders << sales_order_1
            expect(customer.needs_consolidation?).to be(false)
        end        
        it "returns true if there is line_items_need_consolidation is true" do 
            allow(customer).to receive(:line_items_need_consolidation?).and_return(true)
            expect(customer.needs_consolidation?).to be(true)
        end
    
    end
    
    describe "send_orders_to_fishbowl" do
        
        it "voids existing orders" do
        end
        
        it "creates two new orders" do
        end
        
        it "creates a log of all fishbowl write actions" do
        end
    end
    
    
end