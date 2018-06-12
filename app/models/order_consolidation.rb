class OrderConsolidation < ActiveRecord::Base
    #after_commit :run
    has_many :customers, -> { order(:name) }, dependent: :destroy
    has_many :sales_orders, through: :customers
    has_many :products
    has_many :product_errors
    has_many :messages
    
    def create_message(body)
      Message.create order_consolidation: self, body: body
    end
    
    def run
      if connect_to_fishbowl
        create_message "Starting Create Inventory"
        create_inventory
        create_message "Products Found: #{self.products.count}"
        #
        create_message "Starting Create Customers"
        create_customers
        create_message "Customers Found: #{self.customers.count}"
        #
        create_message "Starting Create Sales Orders"
        create_sales_orders
        #
        create_message "Starting Consolidate orders"
        consolidate_orders
        #
        create_message "Write Consolidated Orders to Fishbowl"
        write_consolidated_orders_to_fishbowl
        #
        create_message "Disconnecting From fishbowl"
        disconnect_from_fishbowl
      else
        create_message "Could not connect to fishbowl"
      end
    end
    
    def connect_to_fishbowl
      begin 
        Fishbowl::Connection.connect
        Fishbowl::Connection.login
      rescue Errno::ETIMEDOUT
        Message.create order_consolidation: self, body: 'Connection to Fishbowl timed out.'
        return false
      rescue Fishbowl::Errors::StatusError  => e
        Message.create order_consolidation: self, body: e
        return false
      end
    end
    
    def disconnect_from_fishbowl
      Fishbowl::Connection.close
    end
    
    def decrement_inventory(args)
        product=self.products.find_by_num(args[:product_num])
        product.qty_pickable = product.qty_pickable - args[:qty]
        product.save!
    end
    
    def self.test_method
    end
    
    def write_consolidated_orders_to_fishbowl

      customers.needed_consolidation.each do |customer|
        if customer.void_orders_in_fishbowl
          customer.write_orders_to_fishbowl
        else
          create_message "customer #{customer.name} had a failed sale void, and following voids and creates were cancelled"
        end
      end
    end
    
    def self.get_inventory_xml_from_fishbowl
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.request {
            xml. ExecuteQueryRq {
              xml.Query "SELECT Product.num,
                          QtyInventoryTotals.qtyOnHand as qty_on_hand
                        FROM 
                          Part INNER JOIN Product 
                            ON Part.id = Product.partId 
                          LEFT JOIN QtyInventoryTotals 
                            ON QtyInventoryTotals.partId=Part.id
                            AND QtyInventoryTotals.locationGroupId=1
                          WHERE product.activeFlag=1
                            AND NOT (product.num LIKE 'KEXP%')"
            }
          }
        end
        code, response = Fishbowl::Objects::BaseObject.new.send_request(builder, "ProductGetRs")
        return response
    end
    def self.get_committed_xml_from_fishbowl
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.request {
            xml. ExecuteQueryRq {
              xml.Query "SELECT Product.num,
                          QtyCommitted.qty as qty_committed
                        FROM 
                          Part INNER JOIN Product 
                            ON Part.id = Product.partId 
                          INNER JOIN QtyCommitted 
                            ON QtyCommitted.partId=Part.id
                            AND QtyCommitted.locationGroupId=1
                          WHERE product.activeFlag=1
                            AND NOT (product.num LIKE 'KEXP%')"
            }
          }
        end
        code, response = Fishbowl::Objects::BaseObject.new.send_request(builder, "ProductGetRs")
        return response
    end
    def self.get_not_available_to_pick_xml_from_fishbowl
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.request {
            xml. ExecuteQueryRq {
              xml.Query "SELECT Product.num,
                          QtyNotAvailableToPick.qty as qty_not_available
                        FROM 
                          Part INNER JOIN Product 
                            ON Part.id = Product.partId 
                          INNER JOIN QtyNotAvailableToPick 
                            ON QtyNotAvailableToPick.partId=Part.id
                            AND QtyNotAvailableToPick.locationGroupId=1
                          WHERE product.activeFlag=1
                            AND NOT (product.num LIKE 'KEXP%')"
            }
          }
        end
        code, response = Fishbowl::Objects::BaseObject.new.send_request(builder, "ProductGetRs")
        return response
    end
    
    def create_products
      response=OrderConsolidation.get_inventory_xml_from_fishbowl
      response.xpath("//Row")[1..-1].each do |row|
          puts "IN CREATE PRODUCTS LOOP"
          puts "ROW: #{row.to_s}"
          row_array=row.try(:content).split(',').map{|x| x.gsub("\"","")}
          puts "ROW ARRAY: #{row_array}"
          Product.create num: "#{row_array[0]}", qty_on_hand: (row_array[1] || 0), order_consolidation: self
      end
    end
    
    def update_committed
        response=OrderConsolidation.get_committed_xml_from_fishbowl
        response.xpath("//Row")[1..-1].each do |row|
            row_array=row.try(:content).split(',').map{|x| x.gsub("\"","")}
            product=Product.find_by_num_and_order_consolidation_id row_array[0],self.id
            product.qty_committed = row_array[1] || 0
            product.save!
        end
    end
    
    def update_not_pickable
      response=OrderConsolidation.get_not_available_to_pick_xml_from_fishbowl
      response.xpath("//Row")[1..-1].each do |row|
        row_array=row.try(:content).split(',').map{|x| x.gsub("\"","")}
        product=Product.find_by_num_and_order_consolidation_id row_array[0],self.id
        product.qty_not_pickable = row_array[1] || 0
        puts "ROW ARRAY: #{row_array}"
        puts "PRODUCT: #{product.inspect}"
        product.save!
      end
    end
    
    def create_inventory
        puts "IN CREATE INVENTORY!"
        puts "GETTING INVENTORY"
        create_products
        puts "GETTING COMMITTED"
        update_committed
        puts "GETTING NOT AVAILABLE TO PICK"
        update_not_pickable
        self.products.each do |product|
          qty_pickable=product.qty_on_hand - product.qty_committed - product.qty_not_pickable
          product.qty_pickable_from_fb = qty_pickable
          product.qty_pickable = qty_pickable
          product.save!
        end
    end
    
    def consolidate_orders
        customers.each do |customer|
            if customer.needs_consolidation?
                customer.update_attribute(:needed_consolidation,true)
                customer.consolidate_orders
            else
                customer.update_attribute(:needed_consolidation,false)
            end
        end
    end
    
    def create_customers
      Customer.create_from_open_orders(self)
    end
    
    def create_sales_orders
        self.customers.each do |customer|
          customer.create_sales_orders
        end
    end
end
