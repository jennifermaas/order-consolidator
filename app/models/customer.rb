class Customer < ActiveRecord::Base
    has_many :sales_orders, dependent: :destroy
    has_many :sales_order_items, :through => :sales_orders
    belongs_to :order_consolidation
    validates_presence_of :fb_id
    validates_presence_of :name
    has_one :pickable_order
    has_one :not_pickable_order
    
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
    
    
    def commit_consolidated_orders_to_fishbowl
        # create fishbowl_call for voiding existing orders
        # void existing orders
        # create fishbowl call for creating new orders
        # create new_orders
    end
    
    def needs_consolidation?
        if sales_orders.length > 2
            return true
        elsif line_items_need_consolidation?
            puts "line items need consolication"
            return true
        else
            pickable_sales = sales_orders.find_all{|x| x.pickability_status == 'pickable'}
            not_pickable_sales = sales_orders.find_all{|x| x.pickability_status == 'not_pickable'}
            mixed_sales = sales_orders.find_all{|x| x.pickability_status == 'mixed'}
            empty_sales = sales_orders.find_all{|x| x.pickability_status == 'empty'}
            puts "pickable_sales: #{pickable_sales.inspect}"
            puts "not_pickable_sales.length: #{not_pickable_sales.length}"
            if mixed_sales.count > 0 
                return true
            elsif sales_orders.length == 2
                return (pickable_sales.length == 2) || (not_pickable_sales.length == 2) 
            elsif sales_orders.length == 1 
                return empty_sales.length > 0 
            end
        end
    end
    
    def line_items_need_consolidation?
        sales_order_items.each do |sales_order_item|
            matching_items = sales_order_items.find_all {|x| x.product.num == sales_order_item.product.num}
            return true if matching_items.length > 1
        end
        return false
    end
    
    def consolidated_line_items
        items = []
        sales_order_items.each do |sales_order_item|
            existing_sales_order_item = items.find {|x| x.product.num == sales_order_item.product.num}
            if existing_sales_order_item
                existing_sales_order_item.qty_to_fulfill += sales_order_item.qty_to_fulfill
            else
                items << sales_order_item
            end
        end
        return items
    end
    
    def consolidate_orders
        sales_order_items = consolidated_line_items
        if sales_order_items
            pickable_order=SalesOrder.create num: '1' 
            not_pickable_order=SalesOrder.create num: '2' 
            sales_order_items.each do |sales_order_item|
                puts "****IN consolidated_orders****\n"
                puts "sales_order_item.qty_to_fulfill: #{sales_order_item.qty_to_fulfill}\n"
                puts "sales_order_item.product.qty_pickable: #{sales_order_item.product.qty_pickable}\n"
                
                if sales_order_item.product.qty_pickable == 0
                    not_pickable_order.sales_order_items << sales_order_item.dup
                elsif sales_order_item.qty_to_fulfill <= sales_order_item.product.qty_pickable
                   pickable_order.sales_order_items << sales_order_item.dup
                else
                    pickable_sales_order_item = SalesOrderItem.create(num: sales_order_item.num,qty_to_fulfill: sales_order_item.product.qty_pickable, product: sales_order_item.product, uom_id: sales_order_item.uom_id)
                    pickable_sales_order_item.product=sales_order_item.product
                    not_pickable_sales_order_item = SalesOrderItem.create(num: sales_order_item.num,qty_to_fulfill: (sales_order_item.qty_to_fulfill - sales_order_item.product.qty_pickable), uom_id: sales_order_item.uom_id, product: sales_order_item.product)
                    not_pickable_sales_order_item.product=sales_order_item.product
                    puts "PICKABLE SALES ORDER ITEM: #{pickable_sales_order_item.inspect}"
                    puts "NOT PICKABLE SALES ORDER ITEM: #{not_pickable_sales_order_item.inspect}"
                    pickable_order.sales_order_items << pickable_sales_order_item
                    not_pickable_order.sales_order_items << not_pickable_sales_order_item
                end
            end
            return {pickable: pickable_order, not_pickable: not_pickable_order}
        else
            return false
        end
        
    end

    
    def create_sales_orders
        Fishbowl::Connection.connect
        Fishbowl::Connection.login
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.request {
            xml. GetSOListRq {
              xml.Status 'All Open'
              xml.CustomerName self.name
            }
          }
        end
        code, response = Fishbowl::Objects::BaseObject.new.send_request(builder, "ProductGetRs")
        Fishbowl::Connection.close
        response.xpath("FbiXml//SalesOrder").each do |sales_order_xml|
            num=sales_order_xml.xpath("Number").inner_html
            customer_id=sales_order_xml.xpath("CustomerID").inner_html
            customer_name=sales_order_xml.xpath("CustomerName").inner_html
            sales_order = SalesOrder.create(num: num, customer: self,xml: sales_order_xml.to_s)
            sales_order_xml.xpath("Items//SalesOrderItem").each do |sales_order_item_xml|
                num=sales_order_item_xml.xpath("ID").inner_html
                product_num=sales_order_item_xml.xpath("ProductNumber").inner_html
                qty_to_fulfill=sales_order_item_xml.xpath("Quantity").inner_html
                sales_order_item=SalesOrderItem.create(num: num,product_num: product_num,qty_to_fulfill: qty_to_fulfill, xml: sales_order_item_xml.to_s)
                sales_order.sales_order_items << sales_order_item
            end
            self.sales_orders << sales_order
        end
    end
    
    def self.create_from_open_orders(order_consolidation)
        #
        Fishbowl::Connection.connect
        Fishbowl::Connection.login
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.request {
            xml. ExecuteQueryRq {
              xml.Query "select DISTINCT(customer.id),customer.name FROM so inner join customer on so.customerId=customer.id  WHERE So.statusId IN (10,20,30) AND (customer.name NOT LIKE '%LITA Store%') AND (customer.name NOT LIKE '%KEXP RECORD STORE%')"
            }
          }
        end
        code, response = Fishbowl::Objects::BaseObject.new.send_request(builder, "ProductGetRs")
        Fishbowl::Connection.close
        customers=[]
        response.xpath("//Row")[1..-1].each do |row|
            row_array=row.inner_html.split(',').map{|x| x.gsub("\"","")}
            customers<< Customer.create(fb_id: row_array[0], name: row_array[1], order_consolidation: order_consolidation)
        end
        #
        return customers
    end
    
end