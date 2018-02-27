require 'rails_helper'

RSpec.describe Customer, type: :model do
    
    describe "initialize" do
        it "returns two customers, one with two sales_orders, one with one sales_orderF" do
            sales_orders = []
            sales_orders << SalesOrder.new(num: 1, customer_id: 1)
            sales_orders << SalesOrder.new(num: 2, customer_id: 1)
            sales_orders << SalesOrder.new(num: 3, customer_id: 2)
            customers= Customer.create_customers_from_sales_orders sales_orders
            expect(customers.length).to eq(2)
            expect(customers[0].id).to eq(1)
            expect(customers[1].id).to eq(2)
            expect(customers[0].sales_orders.length).to eq(2)
            expect(customers[1].sales_orders.length).to eq(1)
        end
    end
    
    describe "consolidated_line_items" do
        it "creates a line item list where line items with matching product numbers are merged and their qty_to_fulfill are summed" do
            customer=Customer.new id: 1
            # all product inventories will be 10
            inventory_response_xml=Nokogiri.XML "<FbiXml><FbiMsgsRs statusCode=\"1000\"><InvQtyRs statusCode=\"1000\">\n  <InvQty>\n<QtyOnHand>1</QtyOnHand>\n    <QtyAvailable>10</QtyAvailable>\n    <QtyCommitted>0</QtyCommitted>\n </InvQty></InvQtyRs></FbiMsgsRs></FbiXml>" 
            allow(Product).to receive(:get_inventory_xml_from_fishbowl).and_return(inventory_response_xml)
            sales_order_1 = SalesOrder.new num: '1', customer_id: customer.id
            sales_order_1.sales_order_items << SalesOrderItem.new(num: 'so_item_1',product_num: 1, uom_id: 1,qty_to_fulfill: 10)
            sales_order_1.sales_order_items << SalesOrderItem.new(num: 'so_item_2',product_num: 2, uom_id: 1,qty_to_fulfill: 5)
            sales_order_2 = SalesOrder.new num: '2', customer_id: customer.id
            sales_order_2.sales_order_items << SalesOrderItem.new(num: 'so_item_3',product_num: 1, uom_id: 1,qty_to_fulfill: 12)
            sales_order_2.sales_order_items << SalesOrderItem.new(num: 'so_item_4',product_num: 2, uom_id: 1,qty_to_fulfill: 5)
            customer.sales_orders << sales_order_1
            customer.sales_orders << sales_order_2
            consolidated_line_items=customer.consolidated_line_items
            expect(consolidated_line_items.length).to eq(2)
            expect(consolidated_line_items.find{|x| x.product.num==1}.qty_to_fulfill).to eq(22)
            expect(consolidated_line_items.find{|x| x.product.num==2}.qty_to_fulfill).to eq(10)
        end
    end
    
    describe "consolidated_orders" do
        it "returns pickable order with pickable and partially pickable items and not pickable order with partially pickable items" do
            customer=Customer.new id: '1'
            # all product inventories will be 10
            inventory_response_xml=Nokogiri.XML "<FbiXml><FbiMsgsRs statusCode=\"1000\"><InvQtyRs statusCode=\"1000\">\n  <InvQty>\n<QtyOnHand>1</QtyOnHand>\n    <QtyAvailable>10</QtyAvailable>\n    <QtyCommitted>0</QtyCommitted>\n </InvQty></InvQtyRs></FbiMsgsRs></FbiXml>" 
            allow(Product).to receive(:get_inventory_xml_from_fishbowl).and_return(inventory_response_xml)
            product_1 = Product.new num: 1
            product_2 = Product.new num: 2
            product_3 = Product.new num: 3
            product_4 = Product.new num: 4
            sales_order_1 = SalesOrder.new num: '1', customer_id: customer.id
            sales_order_1.sales_order_items << SalesOrderItem.new(num: 'so_item_1',product_num: product_1.num, uom_id: 1,qty_to_fulfill: 10)
            sales_order_1.sales_order_items << SalesOrderItem.new(num: 'so_item_2',product_num: product_2.num, uom_id: 1,qty_to_fulfill: 5)
            sales_order_2 = SalesOrder.new num: '2', customer_id: customer.id
            sales_order_2.sales_order_items << SalesOrderItem.new(num: 'so_item_3',product_num: product_3.num, uom_id: 1,qty_to_fulfill: 12)
            sales_order_2.sales_order_items << SalesOrderItem.new(num: 'so_item_4',product_num: product_4.num, uom_id: 1,qty_to_fulfill: 5)
            customer.sales_orders << sales_order_1
            customer.sales_orders << sales_order_2
            consolidated_orders = customer.consolidated_orders
            pickable_order=consolidated_orders[:pickable]
            not_pickable_order=consolidated_orders[:not_pickable]
            puts "PICKABLE_ORDER: #{pickable_order.inspect}"
            expect(pickable_order.sales_order_items.length).to eq(4)
            expect(pickable_order.sales_order_items.find {|x| x.product.num==product_1.num}.qty_to_fulfill).to eq(10)
            expect(pickable_order.sales_order_items.find {|x| x.product.num==product_2.num}.qty_to_fulfill).to eq(5)
            expect(pickable_order.sales_order_items.find {|x| x.product.num==product_3.num}.qty_to_fulfill).to eq(10)
            expect(pickable_order.sales_order_items.find {|x| x.product.num==product_4.num}.qty_to_fulfill).to eq(5)
            expect(not_pickable_order.sales_order_items.length).to eq(1)
            expect(not_pickable_order.sales_order_items.find {|x| x.product.num==product_3.num}.qty_to_fulfill).to eq(2)
        end
 
        it "returns not pickable order with items that have 0 pickable quantity" do
            customer=Customer.new id: '1'
            # all product inventories will be 0
            inventory_response_xml=Nokogiri.XML "<FbiXml><FbiMsgsRs statusCode=\"1000\"><InvQtyRs statusCode=\"1000\">\n  <InvQty>\n<QtyOnHand>1</QtyOnHand>\n    <QtyAvailable>0</QtyAvailable>\n    <QtyCommitted>0</QtyCommitted>\n </InvQty></InvQtyRs></FbiMsgsRs></FbiXml>" 
            allow(Product).to receive(:get_inventory_xml_from_fishbowl).and_return(inventory_response_xml)
            product_1 = Product.new num: 1
            product_2 = Product.new num: 2
            product_3 = Product.new num: 3
            product_4 = Product.new num: 4
            puts "PRODUCTS:\n #{product_1.inspect}\n#{product_2.inspect}\n#{product_3.inspect}\n#{product_4.inspect}"
            sales_order_1 = SalesOrder.new num: '1', customer_id: customer.id
            sales_order_1.sales_order_items << SalesOrderItem.new(num: 'so_item_1',product_num: product_1.num, uom_id: 1,qty_to_fulfill: 10)
            sales_order_1.sales_order_items << SalesOrderItem.new(num: 'so_item_2',product_num: product_2.num, uom_id: 1,qty_to_fulfill: 5)
            sales_order_2 = SalesOrder.new num: '2', customer_id: customer.id
            sales_order_2.sales_order_items << SalesOrderItem.new(num: 'so_item_3',product_num: product_3.num, uom_id: 1,qty_to_fulfill: 12)
            sales_order_2.sales_order_items << SalesOrderItem.new(num: 'so_item_4',product_num: product_4.num, uom_id: 1,qty_to_fulfill: 5)
            customer.sales_orders << sales_order_1
            customer.sales_orders << sales_order_2
            consolidated_orders = customer.consolidated_orders
            pickable_order=consolidated_orders[:pickable]
            not_pickable_order=consolidated_orders[:not_pickable]
            puts "NOT_PICKABLE_ORDER: #{not_pickable_order.inspect}"
            expect(not_pickable_order.sales_order_items.length).to eq(4)
            expect(not_pickable_order.sales_order_items.find {|x| x.product.num==product_1.num}.qty_to_fulfill).to eq(10)
            expect(not_pickable_order.sales_order_items.find {|x| x.product.num==product_2.num}.qty_to_fulfill).to eq(5)
            expect(not_pickable_order.sales_order_items.find {|x| x.product.num==product_3.num}.qty_to_fulfill).to eq(12)
            expect(not_pickable_order.sales_order_items.find {|x| x.product.num==product_4.num}.qty_to_fulfill).to eq(5)
            expect(pickable_order.sales_order_items.length).to eq(0)
        end
        
    end
    
    describe "needs_consolidation?" do
        
        before :each do
            @sales_order = SalesOrder.new(num: '123')
            @pickable_sales_order_item_1 = SalesOrderItem.new(qty_to_fulfill: 10)
            @pickable_sales_order_item_1.product = Product.new(num: '123', quantities: {qty_available: 10})
            @pickable_sales_order_item_2 = SalesOrderItem.new(num: 10)
            @pickable_sales_order_item_2.product = Product.new(num: '124', quantities: {qty_available: 10})
            @not_pickable_sales_order_item = SalesOrderItem.new(qty_to_fulfill: 10)
            @not_pickable_sales_order_item.product = Product.new(num: '125', quantities: {qty_available: 0})
            @partially_pickable_sales_order_item = SalesOrderItem.new(qty_to_fulfill: 10)
            @partially_pickable_sales_order_item.product = Product.new(num: '126', quantities: {qty_available: 2})
        end
        
        it "returns true when there are more than two orders" do
            customer = Customer.new(id: '1')
            customer.sales_orders << SalesOrder.new(num: '1')
            customer.sales_orders << SalesOrder.new(num: '2')
            customer.sales_orders << SalesOrder.new(num: '3')
            expect(customer.needs_consolidation?).to be(true)
        end
        
        it "returns true when one order has both a pickable and not pickable item" do
            customer = Customer.new(id: '1')
            mixed_order = SalesOrder.new(num: 1)
            mixed_order.sales_order_items << @pickable_sales_order_item_1
            mixed_order.sales_order_items << @not_pickable_sales_order_item
            customer.sales_orders << mixed_order
            expect(customer.needs_consolidation?).to be(true)
        end
        
        it "returns true when there are two orders with pickable items" do
        end
        
        it "returns false when there are two orders, one with all pickable items and one with all not pickable items" do 
        end
        it "returns true if there is there are two of the same products on any of the customer's orders" do 
            customer = Customer.new(id: '1')
            order_1=SalesOrder.new(num: 1)
            order_2=SalesOrder.new(num: 1)
            @pickable_duplicate_item_1 = SalesOrderItem.new(qty_to_fulfill: 10)
            @pickable_duplicate_item_1.product = Product.new(num: '123', quantities: {qty_available: 10})
            @pickable_duplicate_item_2 = SalesOrderItem.new(qty_to_fulfill: 10)
            @pickable_duplicate_item_2.product = Product.new(num: '123', quantities: {qty_available: 10})
            order_1.sales_order_items << @pickable_duplicate_item_1
            order_2.sales_order_items << @pickable_duplicate_item_2
            customer.sales_orders << order_1
            customer.sales_orders << order_2
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