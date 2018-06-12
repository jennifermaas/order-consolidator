require 'rails_helper'

RSpec.describe Customer, type: :model do
    
    describe "consolidated_line_items" do

        let(:customer) {create(:customer)}
        let(:sales_order_1) {create(:sales_order, customer: customer)}
        let(:sales_order_2) {create(:sales_order, customer: customer)}
        
        it "creates a line item list where line items with matching product numbers are merged and their qty_to_fulfill are summed" do

            sales_order_1.sales_order_items << create(:sales_order_item, product_num: '1', qty_to_fulfill: 10)
            sales_order_1.sales_order_items << create(:sales_order_item, product_num: '2', qty_to_fulfill: 3)
            #
            sales_order_2.sales_order_items << create(:sales_order_item, product_num: '1', qty_to_fulfill: 12)
            sales_order_2.sales_order_items << create(:sales_order_item, product_num: '2', qty_to_fulfill: 5)
            #
            consolidated_line_items=customer.consolidated_line_items
            expect(consolidated_line_items.length).to eq(2)
            expect(consolidated_line_items.find{|x| x.product_num=='1'}.qty_to_fulfill).to eq(22)
            expect(consolidated_line_items.find{|x| x.product_num=='2'}.qty_to_fulfill).to eq(8)
        end
        
        it "creates a line item list even if all items have products with unique product numbers" do 
            sales_order_1.sales_order_items << create(:sales_order_item, product_num: '1', qty_to_fulfill: 10)
            sales_order_1.sales_order_items << create(:sales_order_item, product_num: '2', qty_to_fulfill: 3)
            #
            sales_order_2.sales_order_items << create(:sales_order_item, product_num: '5', qty_to_fulfill: 12)
            sales_order_2.sales_order_items << create(:sales_order_item, product_num: '6', qty_to_fulfill: 5)
            #
            consolidated_line_items=customer.consolidated_line_items
            expect(consolidated_line_items.length).to eq(4)
            expect(consolidated_line_items.find{|x| x.product_num=='1'}.qty_to_fulfill).to eq(10)
            expect(consolidated_line_items.find{|x| x.product_num=='2'}.qty_to_fulfill).to eq(3)
            expect(consolidated_line_items.find{|x| x.product_num=='5'}.qty_to_fulfill).to eq(12)
            expect(consolidated_line_items.find{|x| x.product_num=='6'}.qty_to_fulfill).to eq(5)
        end
        
        
        it "merges two sales order items with same product on the same order" do
            #
            sales_order_1.sales_order_items << create(:sales_order_item, product_num: '1', qty_to_fulfill: 10)
            sales_order_1.sales_order_items << create(:sales_order_item, product_num: '1', qty_to_fulfill: 3)
            #
            consolidated_line_items=customer.consolidated_line_items
            expect(consolidated_line_items.length).to eq(1)
            expect(consolidated_line_items.find{|x| x.product_num=='1'}.qty_to_fulfill).to eq(13)
        end
    end
    
        
    describe "line_items_need_consolidation?" do
        
        let(:customer) {create(:customer)}
        let(:sales_order_1) {create(:sales_order, customer: customer)}
        let(:sales_order_2) {create(:sales_order, customer: customer)}
        
        it "returns true if there is more than one line item with the same product number" do
            sales_order_1.sales_order_items << create(:sales_order_item, product_num: '1', qty_to_fulfill: 10)
            sales_order_1.sales_order_items << create(:sales_order_item, product_num: '2', qty_to_fulfill: 3)
            #
            sales_order_2.sales_order_items << create(:sales_order_item, product_num: '1', qty_to_fulfill: 12)
            sales_order_2.sales_order_items << create(:sales_order_item, product_num: '2', qty_to_fulfill: 5)
            #
            expect(customer.line_items_need_consolidation?).to eq(true)
        end
        
        it "returns true if all line items are unique" do
            sales_order_1.sales_order_items << create(:sales_order_item, product_num: '1', qty_to_fulfill: 10)
            sales_order_1.sales_order_items << create(:sales_order_item, product_num: '2', qty_to_fulfill: 3)
            expect(customer.line_items_need_consolidation?).to eq(false)
        end
    
    end
    
    describe "consolidate_orders" do
        
        before :each do
            OrderConsolidation.skip_callback(:create, :after, :create_sales_orders)
            OrderConsolidation.skip_callback(:create, :after, :consolidate_orders)
            OrderConsolidation.skip_callback(:create, :after, :create_inventory)
            @product_1 = Product.create(num: '1', qty_pickable_from_fb: 10, qty_pickable: 10, order_consolidation: order_consolidation)
            @product_2 = Product.create(num: '2', qty_pickable_from_fb: 10, qty_pickable: 10, order_consolidation: order_consolidation)
            @product_3 = Product.create(num: '3', qty_pickable_from_fb: 0, qty_pickable: 0, order_consolidation: order_consolidation)
            @product_4 = Product.create(num: '4', qty_pickable_from_fb: 10, qty_pickable: 10, order_consolidation: order_consolidation)
        end
        let(:order_consolidation) {create(:order_consolidation)}
        let(:customer) {create(:customer, order_consolidation: order_consolidation)}
        let(:sales_order_1) {create(:sales_order, customer: customer)}
        let(:sales_order_2) {create(:sales_order, customer: customer)}
        
        it "creates a pickable order with pickable and partially pickable items and not pickable order with partially pickable items. and decrements products" do
            #
            sales_order_1.sales_order_items << create(:sales_order_item, product_num: '1', qty_to_fulfill: 10)
            sales_order_1.sales_order_items << create(:sales_order_item, product_num: '2', qty_to_fulfill: 12)
            sales_order_2.sales_order_items << create(:sales_order_item, product_num: '3', qty_to_fulfill: 12)
            sales_order_2.sales_order_items << create(:sales_order_item, product_num: '4', qty_to_fulfill: 5)
            #
            customer.consolidate_orders
            pickable_order=customer.pickable_order
            not_pickable_order=customer.not_pickable_order
            puts "CUSTOMER.orders: #{customer.sales_orders.inspect}"
            puts "sales_order_1.sales_order_items: #{sales_order_1.sales_order_items.inspect}"
            puts "sales_order_2.sales_order_items: #{sales_order_2.sales_order_items.inspect}"
            puts "PICKABLE_ORDER: #{pickable_order.sales_order_items.inspect}"
            puts "NOT PICKABLE_ORDER: #{not_pickable_order.sales_order_items.inspect}"
            expect(pickable_order.sales_order_items.length).to eq(3)
            expect(pickable_order.sales_order_items.find {|x| x.product_num=='1'}.qty_to_fulfill).to eq(10)
            expect(pickable_order.sales_order_items.find {|x| x.product_num=='2'}.qty_to_fulfill).to eq(10)
            expect(pickable_order.sales_order_items.find {|x| x.product_num=='4'}.qty_to_fulfill).to eq(5)
            expect(not_pickable_order.sales_order_items.length).to eq(2)
            expect(not_pickable_order.sales_order_items.find {|x| x.product_num=='2'}.qty_to_fulfill).to eq(2)
            expect(not_pickable_order.sales_order_items.find {|x| x.product_num=='3'}.qty_to_fulfill).to eq(12)
            expect(@product_1.reload.qty_pickable).to eq(0)
            expect(@product_2.reload.qty_pickable).to eq(0)
            expect(@product_3.reload.qty_pickable).to eq(0)
            expect(@product_4.reload.qty_pickable).to eq(5)
            expect(@product_1.reload.qty_pickable_from_fb).to eq(10)
            expect(@product_2.reload.qty_pickable_from_fb).to eq(10)
            expect(@product_3.reload.qty_pickable_from_fb).to eq(0)
            expect(@product_4.reload.qty_pickable_from_fb).to eq(10)
        end
        
        it "puts non inventory items on the not pickable order if there is no pickable order" do
             #
            sales_order_1.sales_order_items << create(:sales_order_item, product_num: 'shipping', qty_to_fulfill: 1, so_item_type_id: "60")
            sales_order_1.sales_order_items << create(:sales_order_item, product_num: '3', qty_to_fulfill: 12)
            #
            customer.consolidate_orders
            pickable_order=customer.pickable_order
            not_pickable_order=customer.not_pickable_order
            puts "CUSTOMER.orders: #{customer.sales_orders.inspect}"
            puts "sales_order_1.sales_order_items: #{sales_order_1.sales_order_items.inspect}"
            puts "sales_order_2.sales_order_items: #{sales_order_2.sales_order_items.inspect}"
            puts "PICKABLE_ORDER: #{pickable_order.sales_order_items.inspect}"
            puts "NOT PICKABLE_ORDER: #{not_pickable_order.sales_order_items.inspect}"
            expect(pickable_order.sales_order_items.length).to eq(0)
            expect(not_pickable_order.sales_order_items.length).to eq(2)
            expect(not_pickable_order.sales_order_items.find {|x| x.product_num=='shipping'}.qty_to_fulfill).to eq(1)
            expect(not_pickable_order.sales_order_items.find {|x| x.product_num=='3'}.qty_to_fulfill).to eq(12)
        end
        
        it "puts non inventory items on the pickable order if there is a pickable order" do
            #
            sales_order_1.sales_order_items << create(:sales_order_item, product_num: 'shipping', qty_to_fulfill: 1, so_item_type_id: "60")
            sales_order_1.sales_order_items << create(:sales_order_item, product_num: '1', qty_to_fulfill: 3)
            sales_order_1.sales_order_items << create(:sales_order_item, product_num: '3', qty_to_fulfill: 12)
            #
            customer.consolidate_orders
            pickable_order=customer.pickable_order
            not_pickable_order=customer.not_pickable_order
            puts "CUSTOMER.orders: #{customer.sales_orders.inspect}"
            puts "sales_order_1.sales_order_items: #{sales_order_1.sales_order_items.inspect}"
            puts "sales_order_2.sales_order_items: #{sales_order_2.sales_order_items.inspect}"
            puts "PICKABLE_ORDER: #{pickable_order.sales_order_items.inspect}"
            puts "NOT PICKABLE_ORDER: #{not_pickable_order.sales_order_items.inspect}"
            expect(pickable_order.sales_order_items.length).to eq(2)
            expect(not_pickable_order.sales_order_items.length).to eq(1)
            expect(pickable_order.sales_order_items.find {|x| x.product_num=='shipping'}.qty_to_fulfill).to eq(1)
            expect(pickable_order.sales_order_items.find {|x| x.product_num=='1'}.qty_to_fulfill).to eq(3)
            expect(not_pickable_order.sales_order_items.find {|x| x.product_num=='3'}.qty_to_fulfill).to eq(12)
        end
        
    end
    
    
    describe "needs_consolidation?" do
        before :each do
            OrderConsolidation.skip_callback(:create, :after, :create_sales_orders)
            OrderConsolidation.skip_callback(:create, :after, :consolidate_orders)
            OrderConsolidation.skip_callback(:create, :after, :create_inventory)
            @product_1 = Product.create(num: '10', qty_pickable_from_fb: 10, qty_pickable: 10, order_consolidation: order_consolidation)
            @product_2 = Product.create(num: '12', qty_pickable_from_fb: 12, qty_pickable: 12, order_consolidation: order_consolidation)
            @product_3 = Product.create(num: '0', qty_pickable_from_fb: 0, qty_pickable: 0, order_consolidation: order_consolidation)
            @product_4 = Product.create(num: '00', qty_pickable_from_fb: 0, qty_pickable: 0, order_consolidation: order_consolidation)
        end
        let(:order_consolidation) {create(:order_consolidation)}
        let(:pickable_sales_order_item) {create(:sales_order_item, qty_to_fulfill: 10, product_num: '10')}
        let(:pickable_sales_order_item_2) {create(:sales_order_item, qty_to_fulfill: 10, product_num: '12')}
        let(:not_pickable_sales_order_item) {create(:sales_order_item, qty_to_fulfill: 10, product_num: '0')}
        let(:not_pickable_sales_order_item_2) {create(:sales_order_item, qty_to_fulfill: 10, product_num: '00')}
        let(:mixed_sales_order_item) {create(:sales_order_item, qty_to_fulfill: 12, product_num: '10')}
        let(:customer) {create(:customer, order_consolidation: order_consolidation)}
        
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