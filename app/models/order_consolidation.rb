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
        create_message "Starting Create Sales Orders"
        create_sales_orders
        #
        create_message "Checking for Committed Priority 3 Orders"
        check_for_committed_priority_3_orders
        #
        create_message "Starting Consolidate orders"
        consolidate_orders
        #
        #create_message "Write Consolidated Orders to Fishbowl"
        write_consolidated_orders_to_fishbowl
        #
        #create_message "Send new available_to_pick to website"
        #send_available_to_pick_to_website
        #
        create_message "Disconnecting From fishbowl"
        disconnect_from_fishbowl
      else
        create_message "Could not connect to fishbowl"
      end
    end
    
    def send_available_to_pick_to_website
      require 'net/http'
      #uri=URI.parse "http://lightintheattic.net/api/products/update_multiple.json?user_credentials=TvTCvb6c-kZFMza1kTdm"
      uri=URI.parse "#{Rails.configuration.lita_api_url}/api/products/update_multiple.json?user_credentials=#{Rails.configuration.lita_api_user_credentials}"
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Put.new(uri.request_uri)
      oc=self
      products_array=oc.products.collect{|p| {quickbooks_product_number: p.num, available_to_pick: p.qty_pickable}}
      products_json = { products: products_array }.to_json
      request.body = products_json
      request['Content-Type'] = 'application/json'
      response = http.request(request)
      puts response
    end
    
    def check_for_committed_priority_3_orders
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.request {
          xml.PickQueryRq {
            xml.Status "Committed"
            xml.Priority "3-Normal"
            xml.RecordCount "1000"
            xml.PickType "Pick"
          }
        }
      end
      code, response = Fishbowl::Objects::BaseObject.new.send_request(builder, "ProductGetRs")
      order_numbers = []
      response.xpath("//PickSearchItem").each do |sales_order_xml|
          order_type_number = sales_order_xml.at_xpath("OrderTypeNumber").content
          order_numbers << order_type_number[2..-1]
      end
      order_numbers.each do |order_number|
        sales_order = self.sales_orders.find_by_num order_number
        if sales_order
          sales_order.committed=true
          sales_order.save
          sales_order.customer.has_committed=true
          sales_order.customer.save
          create_message "Customer #{sales_order.customer.name} has a committed priority 3 order: #{sales_order.num}.  This customer will not be included in consolidation"
        end
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
        create_message "starting customer #{customer.name}"
        if customer.void_orders_in_fishbowl
          create_message "finished voids"
          customer.write_orders_to_fishbowl
          create_message "finished writing orders"
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
        customers.not_committed.each do |customer|
            if customer.needs_consolidation?
                customer.update_attribute(:needed_consolidation,true)
                customer.consolidate_orders
            else
                customer.update_attribute(:needed_consolidation,false)
            end
        end
    end
    
    def create_sales_orders
      require 'csv'
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.request {
          xml. ExecuteQueryRq {
            xml.Query  "SELECT customer.id,customer.name, customer.number, So.num
                        FROM So INNER JOIN Customer on So.CustomerId=Customer.id
                        WHERE  (So.statusId=20)
                          AND NOT (num LIKE 'G%')
                          AND NOT (num LIKE 'g%')
                          AND NOT (num LIKE 'R%')
                          AND NOT (num LIKE 'r%')
                          AND NOT (num LIKE '@%')
                          AND (So.customerId NOT IN (328,1603,333,758,1576,1319,1427,1365)) 
                          AND NOT (customer.name LIKE '%Alliance%')
                          AND NOT (customer.name LIKE '%All Media Supply%')
                          AND NOT (customer.name LIKE '%Baker%')
                          AND NOT (customer.name LIKE '%PROMO%')
                          AND NOT (customer.name LIKE '%LITA Store%')
                          AND NOT (customer.name LIKE '%Cargo%')
                          AND NOT (customer.name LIKE '%PIAS%')
                          AND NOT (customer.name LIKE '%Inertia%')
                          AND NOT (customer.name = 'Revolver')
                          AND NOT (customer.name = 'Revolver USA')
                          AND NOT (customer.name LIKE '%Outside%')
                          AND NOT (customer.name LIKE '%SRD%')
                          AND NOT (customer.name LIKE '%Border%')
                          AND NOT (customer.name LIKE '%Southbound%')
                          AND NOT (customer.name LIKE '%Cobraside%')
                          AND NOT (customer.name LIKE '%Tsunami%')
                          AND NOT (customer.name LIKE '%Pop Up Event%')
                        ORDER BY customer.name"
          }
        }
      end
      code, response = Fishbowl::Objects::BaseObject.new.send_request(builder, "ProductGetRs")
      previous_customer_name=""
      response.xpath("//Row")[1..-1].each do |row|
        row_array=row.content.parse_csv
        unless previous_customer_name == row_array[1]
          @customer = Customer.create(fb_id: row_array[0], name: row_array[1], account_number: row_array[2], order_consolidation: self)
          previous_customer_name = row_array[1]
        end
        logger.info "***** @customer = #{@customer.inspect} "
        builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
          xml.request {
            xml.LoadSORq {
              xml.Number "#{row_array[3]}"
            }
          }
        end
        code, response = Fishbowl::Objects::BaseObject.new.send_request(builder, "GetSOListRq")
        sales_order_params = {}
        response.xpath("FbiXml//SalesOrder").each do |sales_order_xml|
            sales_order_params["num"]=sales_order_xml.at_xpath("Number").try(:content)
            sales_order_params["customer_id"]=@customer.id
            sales_order_params["customer_contact"]=sales_order_xml.at_xpath("CustomerContact").try(:content).force_encoding('iso-8859-1').encode('utf-8')
            sales_order_params["bill_to_name"]=sales_order_xml.at_xpath("BillTo//Name").try(:content).force_encoding('iso-8859-1').encode('utf-8')
            sales_order_params["bill_to_address"]=sales_order_xml.at_xpath("BillTo//AddressField").try(:content).force_encoding('iso-8859-1').encode('utf-8')
            sales_order_params["bill_to_city"]=sales_order_xml.at_xpath("BillTo//City").try(:content).force_encoding('iso-8859-1').encode('utf-8')
            sales_order_params["bill_to_state"]=sales_order_xml.at_xpath("BillTo//State").try(:content)
            sales_order_params["bill_to_zip"]=sales_order_xml.at_xpath("BillTo//Zip").try(:content)
            sales_order_params["bill_to_country"]=sales_order_xml.at_xpath("BillTo//Country").try(:content)
            sales_order_params["ship_to_name"]=sales_order_xml.at_xpath("Ship//Name").try(:content).force_encoding('iso-8859-1').encode('utf-8')
            sales_order_params["ship_to_address"]=sales_order_xml.at_xpath("Ship//AddressField").try(:content).force_encoding('iso-8859-1').encode('utf-8')
            sales_order_params["ship_to_city"]=sales_order_xml.at_xpath("Ship//City").try(:content).force_encoding('iso-8859-1').encode('utf-8')
            sales_order_params["ship_to_state"]=sales_order_xml.at_xpath("Ship//State").try(:content)
            sales_order_params["ship_to_zip"]=sales_order_xml.at_xpath("Ship//Zip").try(:content)
            sales_order_params["ship_to_country"]=sales_order_xml.at_xpath("Ship//Country").try(:content)
            sales_order_params["ship_to_residential"]
            sales_order_params["carrier_name"]=sales_order_xml.at_xpath("Carrier").try(:content)
            sales_order_params["tax_rate_name"]=sales_order_xml.at_xpath("TaxRateName").try(:content)
            sales_order_params["priority_id"]=sales_order_xml.at_xpath("PriorityId").try(:content)
            sales_order_params["po_num"]=sales_order_xml.at_xpath("PoNum").try(:content)
            sales_order_params["date"]=sales_order_xml.at_xpath("CreatedDate").try(:content)
            sales_order_params["salesman"]=sales_order_xml.at_xpath("Salesman").try(:content)
            sales_order_params["shipping_terms"]=sales_order_xml.at_xpath("ShippingTerms").try(:content)
            sales_order_params["payment_terms"]=sales_order_xml.at_xpath("PaymentTerms").try(:content)
            sales_order_params["fob"]=sales_order_xml.at_xpath("FOB").try(:content)
            sales_order_params["note"]=sales_order_xml.at_xpath("Note").try(:content)
            sales_order_params["quickbooks_class_name"]=sales_order_xml.at_xpath("QuickBooksClassName").try(:content)
            sales_order_params["location_group_name"]=sales_order_xml.at_xpath("LocationGroup").try(:content)
            sales_order_params["fulfillment_date"]=sales_order_xml.at_xpath("DateCompleted").try(:content)
            sales_order_params["url"]=sales_order_xml.at_xpath("URL").try(:content)
            sales_order_params["carrier_service"]=""
            sales_order_params["currency_name"]=sales_order_xml.at_xpath("currencyName").try(:content)
            sales_order_params["currency_rate"]=sales_order_xml.at_xpath("currencyRate").try(:content)
            sales_order_params["price_is_home_currency"]=sales_order_xml.at_xpath("PriceIsHomeCurrency").try(:content)
            sales_order_params["date_expired"]=""
            sales_order_params["phone"]=""
            sales_order_params["email"]=""
            sales_order = SalesOrder.create(sales_order_params)
            sales_order_xml.xpath("Items//SalesOrderItem").each do |sales_order_item_xml|
              sales_order_item_params={}
              sales_order_item_params["num"]=sales_order_item_xml.at_xpath("ID").try(:content)
              sales_order_item_params["sales_order_id"]=sales_order.id
              sales_order_item_params["product_num"]=sales_order_item_xml.at_xpath("ProductNumber").try(:content).force_encoding('iso-8859-1').encode('utf-8')
              product=""
              sales_order_item_params["so_item_type_id"]=sales_order_item_xml.at_xpath("ItemType").try(:content)
              sales_order_item_params["qty_to_fulfill"]=sales_order_item_xml.at_xpath("Quantity").try(:content)
              sales_order_item_params["uom"]=sales_order_item_xml.at_xpath("UOMCode").try(:content)
              sales_order_item_params["product_price"]=sales_order_item_xml.at_xpath("ProductPrice").try(:content)
              sales_order_item_params["taxable"]=sales_order_item_xml.at_xpath("Taxable").try(:content)
              sales_order_item_params["note"]=sales_order_item_xml.at_xpath("Note").try(:content).force_encoding('iso-8859-1').encode('utf-8')
              sales_order_item_params["quickbooks_class_name"]=sales_order_item_xml.at_xpath("QuickBooksClassName").try(:content)
              sales_order_item_params["show_item"]=sales_order_item_xml.at_xpath("ShowItemFlag").try(:content)
              sales_order_item_params["revision_level"]=sales_order_item_xml.at_xpath("RevisionLevel").try(:content)
              sales_order_item_params["kit_item"]=sales_order_item_xml.at_xpath("KitItem").try(:content)
              sales_order_item=SalesOrderItem.create(sales_order_item_params)
            end
        end
      end
    end
end
