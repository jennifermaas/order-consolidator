class OrderConsolidation < ActiveRecord::Base
    after_commit :run
    has_many :customers, -> { order(:name) }, dependent: :destroy
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
        create_message "Starting Create Customers"
        create_customers
        create_message "Starting Create Sales Orders"
        create_sales_orders
        create_message "Starting Consolidate orders"
        consolidate_orders
        create_message "Write Consolidated Orders to Fishbowl"
        write_consolidated_orders_to_fishbowl
        create_message "Disconnecting From fishbowl"
        disconnect_from_fishbowl
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
    
    def write_consolidated_orders_to_fishbowl

      customers.needed_consolidation.each do |customer|
        customer.write_orders_to_fishbowl
        customer.void_orders_in_fishbowl
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
                            AND QtyInventoryTotals.locationGroupId=1"
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
                            AND QtyCommitted.locationGroupId=1"
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
                            AND QtyNotAvailableToPick.locationGroupId=1"
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
          builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
            xml.request {
              xml.GetSOListRq {
                xml.Status 'All Open'
                xml.LocationGroupName 'LITA'
                xml.CustomerName customer.name
              }
            }
          end
          code, response = Fishbowl::Objects::BaseObject.new.send_request(builder, "ProductGetRs")
          sales_order_params = {}
          response.xpath("FbiXml//SalesOrder").each do |sales_order_xml|
            unless (sales_order_xml.xpath("Number").inner_html[0]=="G") || (sales_order_xml.xpath("Status").inner_html=="10") || (sales_order_xml.xpath("Number").inner_html[0]=="R")
              sales_order_params["num"]=sales_order_xml.at_xpath("Number").try(:content)
              sales_order_params["customer_id"]=customer.id
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
                sales_order_item=SalesOrderItem.create(sales_order_item_params)
              end
            end
          end
        end
    end
end
