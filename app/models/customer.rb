class Customer
    attr_accessor :id, :name, :sales_orders
    
    def update_fishbowl
        if needs_consolidation?
            sales_orders.each do |sales_order|
                sales_order.void_in_fishbowl
            end
            consolidated_orders.each do |sales_order|
                sales_order.write_to_fishbowl
            end
        end
    end
    
    def initialize(args)
        @id=args[:id]
        @sales_orders=[]
    end
    
    def commit_consolidated_orders_to_fishbowl
        # create fishbowl_call for voiding existing orders
        # void existing orders
        # create fishbowl call for creating new orders
        # create new_orders
    end
    
    def needs_consolidation?
        if sales_orders.length > 2
            return true
        elsif consolidated_line_items[:line_items_needed_consolidation]
            puts "line items need consolication"
            return true
        else
            pickable_sales = sales_orders.find_all{|x| x.pickability_status == 'pickable'}
            not_pickable_sales = sales_orders.find_all{|x| x.pickability_status == 'not_pickable'}
            mixed_sales = sales_orders.find_all{|x| x.pickability_status == 'mixed'}
            empty_sales = sales_orders.find_all{|x| x.pickability_status == 'empty'}
            if mixed_sales.count > 0 
                return true
            elsif sales_orders.length == 2
                return (pickable_sales.length == 1) && (not_pickable_sales.length == 1) 
            elsif sales_orders.length == 1 
                return empty_sales.length == 0 
            end
        end
    end
    
    def consolidated_line_items
        sales_order_items = []
        line_items_needed_consolidation=false
        self.sales_orders.each do |sales_order|
            sales_order.sales_order_items.each do |sales_order_item|
                puts "SALES ORDER ITEM: #{sales_order_item.inspect}"
                existing_sales_order_item = sales_order_items.find {|x| x.product.num == sales_order_item.product.num}
                if existing_sales_order_item
                    line_items_needed_consolidation = true
                    existing_sales_order_item.qty_to_fulfill += sales_order_item.qty_to_fulfill
                else
                    sales_order_items << SalesOrderItem.new(num: sales_order_item.num, qty_to_fulfill: sales_order_item.qty_to_fulfill, product_num: sales_order_item.product.num, uom_id: sales_order_item.uom_id)
                end
            end
        end
        return {sales_order_items: sales_order_items, line_items_needed_consolidation: line_items_needed_consolidation }
    end
    
    def consolidated_orders
        pickable_order=SalesOrder.new num: '1' 
        not_pickable_order=SalesOrder.new num: '2' 
        sales_order_items = consolidated_line_items[:sales_order_items]
        sales_order_items.each do |sales_order_item|
            if sales_order_item.qty_to_fulfill <= sales_order_item.product.qty_pickable
                pickable_order.sales_order_items << sales_order_item
            elsif sales_order_item.product.qty_pickable == 0
                not_pickable_order.sales_order_items << sales_order_item
            else
                pickable_sales_order_item = SalesOrderItem.new(num: sales_order_item.num,qty_to_fulfill: sales_order_item.product.qty_pickable, product_num: sales_order_item.product.num, uom_id: sales_order_item.uom_id)
                not_pickable_sales_order_item = SalesOrderItem.new(num: sales_order_item.num,qty_to_fulfill: (sales_order_item.qty_to_fulfill - sales_order_item.product.qty_pickable), product_num: sales_order_item.product.num, uom_id: sales_order_item.uom_id)
                pickable_order.sales_order_items << pickable_sales_order_item
                not_pickable_order.sales_order_items << not_pickable_sales_order_item
            end
        end
        return {pickable: pickable_order, not_pickable: not_pickable_order}
    end
    
    def self.create_customers_from_open_orders ()
        sales_orders=SalesOrder.find_open_orders
        customers=[]
        sales_orders.each do |sales_order|
            customer_index = customers.index { |x| x.id == sales_order.customer_id }
            if customer_index
                customer=customers[customer_index]
            else
                customer= Customer.new(id: sales_order.customer_id, name: sales_order.customer_name)
                customers << customer
            end    
            customer.sales_orders << sales_order
        end 
        return customers
    end
    
end