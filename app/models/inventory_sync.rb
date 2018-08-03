class InventorySync < ActiveRecord::Base
    has_many :products
    
    def create_message(body)
      Message.create inventory_sync: self, body: body
    end
    
    def run
      if connect_to_fishbowl
        create_message "Connected to Fishbowl"
        create_message "Starting Create Inventory"
        create_inventory
        create_message "Products Found: #{self.products.count}"
        #
        create_message "Send Available to Pick to Website"
        send_available_to_pick_to_website
        #
        create_message "Disconnecting From fishbowl"
        disconnect_from_fishbowl
      else
        create_message "Could not connect to fishbowl"
      end
    end
    
    
    def send_available_to_pick_to_website
      require 'net/http'
      uri=URI.parse "#{Rails.configuration.lita_api_url}/api/products/update_multiple.json?user_credentials=#{Rails.configuration.lita_api_user_credentials}"
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Put.new(uri.request_uri)
      products_array=self.products.collect{|p| {quickbooks_product_number: p.num, available_to_pick: p.qty_pickable}}
      products_json = { products: products_array }.to_json
      request.body = products_json
      request['Content-Type'] = 'application/json'
      response = http.request(request)
      puts response
    end
    
    def connect_to_fishbowl
      begin 
        Fishbowl::Connection.connect
        Fishbowl::Connection.login
      rescue Errno::ETIMEDOUT
        Message.create inventory_sync: self, body: 'Connection to Fishbowl timed out.'
        return false
      rescue Fishbowl::Errors::StatusError  => e
        Message.create inventory_sync: self, body: e
        return false
      end
    end
    
    def disconnect_from_fishbowl
      Fishbowl::Connection.close
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
      response=InventorySync.get_inventory_xml_from_fishbowl
      response.xpath("//Row")[1..-1].each do |row|
          puts "IN CREATE PRODUCTS LOOP"
          puts "ROW: #{row.to_s}"
          row_array=row.try(:content).split(',').map{|x| x.gsub("\"","")}
          puts "ROW ARRAY: #{row_array}"
          Product.create num: "#{row_array[0]}", qty_on_hand: (row_array[1] || 0), inventory_sync: self
      end
    end
    
    def update_committed
        response=InventorySync.get_committed_xml_from_fishbowl
        response.xpath("//Row")[1..-1].each do |row|
            row_array=row.try(:content).split(',').map{|x| x.gsub("\"","")}
            product=Product.find_by_num_and_inventory_sync_id row_array[0],self.id
            product.qty_committed = row_array[1] || 0
            product.save!
        end
    end
    
    def update_not_pickable
      response=InventorySync.get_not_available_to_pick_xml_from_fishbowl
      response.xpath("//Row")[1..-1].each do |row|
        row_array=row.try(:content).split(',').map{|x| x.gsub("\"","")}
        product=Product.find_by_num_and_inventory_sync_id row_array[0],self.id
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
end
