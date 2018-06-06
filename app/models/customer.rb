class Customer < ActiveRecord::Base
    has_many :sales_orders, dependent: :destroy
    has_many :sales_order_items, :through => :sales_orders
    belongs_to :order_consolidation
    validates_presence_of :fb_id
    #validates_presence_of :name
    belongs_to :pickable_order, class_name: 'SalesOrder', foreign_key: "pickable_order_id", dependent: :destroy
    belongs_to :not_pickable_order, class_name: 'SalesOrder', foreign_key: "not_pickable_order_id", dependent: :destroy
    
    scope :needed_consolidation, -> { where(needed_consolidation: true) }
    scope :did_not_need_consolidation, -> { where(needed_consolidation: false) }
    
    def void_orders_in_fishbowl
        self.sales_orders.each do |order|
          return false unless order.void_in_fishbowl
        end
    end
    
    def write_orders_to_fishbowl
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.request {
            xml. ImportRq {
              xml.Type 'ImportSalesOrder'
              xml.Rows{
                xml.Row order_consolidation.customers.needed_consolidation[0].sales_orders[0].xml_hash.keys.map{|x| "\"#{x}\""}.join(",") # get headers from first order
                xml.Row order_consolidation.customers.needed_consolidation[0].sales_order_items[0].xml_hash.keys.map{|x| "\"#{x}\""}.join(",")
                if self.needed_consolidation
                  if self.pickable_order.sales_order_items.length>0
                    xml.Row self.pickable_order.xml_hash.values.map{|x| "\"#{x}\""}.join(",")
                    self.pickable_order.sales_order_items.each do |sales_order_item|
                      xml.Row sales_order_item.xml_hash.values.map{|x| "\"#{x}\""}.join(",")
                    end
                  end
                  if self.not_pickable_order.sales_order_items.length>0
                    xml.Row self.not_pickable_order.xml_hash.values.map{|x| "\"#{x}\""}.join(",")
                    self.not_pickable_order.sales_order_items.each do |sales_order_item|
                      xml.Row sales_order_item.xml_hash.values.map{|x| "\"#{x}\""}.join(",")
                    end
                  end
                end
              }
            }
          }
        end
        code,response=Fishbowl::Objects::BaseObject.new.send_request(builder, 'ImportRq')
        if response.xpath("//ImportRs/@statusCode").first.value != "1000"
            self.order_consolidation.create_message "Import failed for customer: #{self.name}.  #{response.xpath("//ImportRs/@statusMessage").first.value}"
        end
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
        puts "IN LINE ITEMS NEED CONSOLIDATION?"
        sales_order_items.each do |sales_order_item|
            puts "IN LOOP"
            matching_items = sales_order_items.find_all {|x| x.product_num == sales_order_item.product_num}
            if matching_items.length > 1
                self.update_attribute(:line_items_needed_consolidation,true)
                return true
            end
        end
        self.update_attribute(:line_items_needed_consolidation,false)
        return false
    end
    
    def consolidated_line_items
        items = []
        sales_order_items.each do |sales_order_item|
            existing_sales_order_item = items.find {|x| x.product_num == sales_order_item.product_num}
            if existing_sales_order_item
                existing_sales_order_item.qty_to_fulfill += sales_order_item.qty_to_fulfill
            else
                items << sales_order_item.dup
            end
        end
        return items
    end
    
    def consolidate_orders
        sales_order_items = consolidated_line_items
        if sales_order_items
            pickable_order=SalesOrder.create
            not_pickable_order=SalesOrder.create
            sales_order_items.each do |sales_order_item|
                if sales_order_item.qty_pickable == 0
                    item=sales_order_item.dup
                    item.save
                    not_pickable_order.sales_order_items << item
                elsif sales_order_item.qty_to_fulfill <= sales_order_item.qty_pickable
                   item=sales_order_item.dup
                   item.save
                   pickable_order.sales_order_items << item
                   self.order_consolidation.decrement_inventory(product_num: sales_order_item.product_num, qty: sales_order_item.qty_to_fulfill)
                else
                    pickable_sales_order_item = SalesOrderItem.create(num: sales_order_item.num,qty_to_fulfill: sales_order_item.qty_pickable, product_num: sales_order_item.product_num, uom_id: sales_order_item.uom_id)
                    not_pickable_sales_order_item = SalesOrderItem.create(num: sales_order_item.num,qty_to_fulfill: (sales_order_item.qty_to_fulfill - sales_order_item.qty_pickable), uom_id: sales_order_item.uom_id, product_num: sales_order_item.product_num)
                    pickable_order.sales_order_items << pickable_sales_order_item
                    not_pickable_order.sales_order_items << not_pickable_sales_order_item
                    self.order_consolidation.decrement_inventory(product_num: pickable_sales_order_item.product_num, qty: pickable_sales_order_item.qty_to_fulfill)
                end
            end
            self.pickable_order = pickable_order
            self.not_pickable_order = not_pickable_order
            self.save
        else
            return false
        end
        
    end
    
    def self.create_from_open_orders(order_consolidation)
        require 'csv'
        #
        # KEXP Customer 1319
        # KEXP RECORD STORE 1427
        # KEXPPP 1365
        # LITA Store 328
        # PROMOS 333
        # Employee Promos 1576
        # DAILY PROMOS 758
        # Damages & Defects 1603
        # 328,1603,333,758,1576,1319,1427,1365
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.request {
            xml. ExecuteQueryRq {
              xml.Query "select DISTINCT(customer.id),customer.name 
                                FROM so inner join customer on so.customerId=customer.id  
                                WHERE So.statusId IN (20,25) 
                                  AND (So.customerId NOT IN (328,1603,333,758,1576,1319,1427,1365)) 
                                  AND (     (customer.name LIKE '%TOOST%')
                                        OR  (customer.name='Generation Records')
                                        OR  (customer.name='Turntable Lab')
                                        OR  (customer.name='A Day In The Life')
                                        OR  (customer.name='Jared Kusmit')
                                        OR  (customer.name='Yellow Dog')
                                        OR  (customer.name='Shangri-La')
                                        OR  (customer.name='Keene On Vinyl')
                                        OR  (customer.name='Kops')
                                        OR  (customer.name='Culture Clash')
                                        OR  (customer.name='RPM'))"
            }
          }
        end
        code, response = Fishbowl::Objects::BaseObject.new.send_request(builder, "ProductGetRs")
        customers=[]
        response.xpath("//Row")[1..-1].each do |row|
            row_array=row.content.parse_csv
            customers<< Customer.create(fb_id: row_array[0], name: row_array[1], order_consolidation: order_consolidation)
        end
        #
        return customers
    end
    
end