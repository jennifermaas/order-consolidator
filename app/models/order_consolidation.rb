class OrderConsolidation < ActiveRecord::Base
    after_commit :connect_to_fishbowl, :create_inventory, :create_customers, :create_sales_orders, :consolidate_orders, :write_consolidated_orders_to_fishbowl, :disconnect_from_fishbowl
    has_many :customers, -> { order(:name) }, dependent: :destroy
    has_many :products
    has_many :product_errors

    def decrement_inventory(args)
        product=self.products.find_by_num(args[:product_num])
        product.qty_pickable = product.qty_pickable - args[:qty]
        product.save!
    end
    
    def connect_to_fishbowl
      Fishbowl::Connection.connect
      Fishbowl::Connection.login
    end
    
    def disconnect_from_fishbowl
      Fishbowl::Connection.close
    end
    
    def write_consolidated_orders_to_fishbowl

      customers.needed_consolidation.each do |customer|
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.request {
            xml. ImportRq {
              xml.Type 'ImportSalesOrder'
              xml.Rows{
                xml.Row customers.needed_consolidation[0].sales_orders[0].xml_hash.keys.map{|x| "\"#{x}\""}.join(",") # get headers from first order
                xml.Row customers.needed_consolidation[0].sales_order_items[0].xml_hash.keys.map{|x| "\"#{x}\""}.join(",")
                if customer.needed_consolidation
                  if customer.pickable_order.sales_order_items.length>0
                    xml.Row customer.pickable_order.xml_hash.values.map{|x| "\"#{x}\""}.join(",")
                    customer.pickable_order.sales_order_items.each do |sales_order_item|
                      xml.Row sales_order_item.xml_hash.values.map{|x| "\"#{x}\""}.join(",")
                    end
                  end
                  if customer.not_pickable_order.sales_order_items.length>0
                    xml.Row customer.not_pickable_order.xml_hash.values.map{|x| "\"#{x}\""}.join(",")
                    customer.not_pickable_order.sales_order_items.each do |sales_order_item|
                      xml.Row sales_order_item.xml_hash.values.map{|x| "\"#{x}\""}.join(",")
                    end
                  end
                end
              }
            }
          }
        end
        Fishbowl::Objects::BaseObject.new.send_request(builder, 'ImportRq')
        customer.sales_orders.each do |order|
          order.void_in_fishbowl
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
          builder = Nokogiri::XML::Builder.new do |xml|
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
              sales_order_params["customer_contact"]=sales_order_xml.at_xpath("CustomerContact").try(:content)
              sales_order_params["bill_to_name"]=sales_order_xml.at_xpath("BillTo//Name").try(:content)
              sales_order_params["bill_to_address"]=sales_order_xml.at_xpath("BillTo//AddressField").try(:content)
              sales_order_params["bill_to_city"]=sales_order_xml.at_xpath("BillTo//City").try(:content)
              sales_order_params["bill_to_state"]=sales_order_xml.at_xpath("BillTo//State").try(:content)
              sales_order_params["bill_to_zip"]=sales_order_xml.at_xpath("BillTo//Zip").try(:content)
              sales_order_params["bill_to_country"]=sales_order_xml.at_xpath("BillTo//Country").try(:content)
              sales_order_params["ship_to_name"]=sales_order_xml.at_xpath("Ship//Name").try(:content)
              sales_order_params["ship_to_address"]=sales_order_xml.at_xpath("Ship//AddressField").try(:content)
              sales_order_params["ship_to_city"]=sales_order_xml.at_xpath("Ship//City").try(:content)
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
                sales_order_item_params["product_num"]=sales_order_item_xml.at_xpath("ProductNumber").try(:content)
                product=""
                sales_order_item_params["so_item_type_id"]=sales_order_item_xml.at_xpath("ItemType").try(:content)
                sales_order_item_params["qty_to_fulfill"]=sales_order_item_xml.at_xpath("Quantity").try(:content)
                sales_order_item_params["uom"]=sales_order_item_xml.at_xpath("UOMCode").try(:content)
                sales_order_item_params["product_price"]=sales_order_item_xml.at_xpath("ProductPrice").try(:content)
                sales_order_item_params["taxable"]=sales_order_item_xml.at_xpath("Taxable").try(:content)
                sales_order_item_params["note"]=sales_order_item_xml.at_xpath("Note").try(:content)
                sales_order_item_params["quickbooks_class_name"]=sales_order_item_xml.at_xpath("QuickBooksClassName").try(:content)
                sales_order_item_params["show_item"]=sales_order_item_xml.at_xpath("ShowItemFlag").try(:content)
                sales_order_item_params["revision_level"]=sales_order_item_xml.at_xpath("RevisionLevel").try(:content)
                sales_order_item=SalesOrderItem.create(sales_order_item_params)
              end
            end
          end
        end
    end
  
    def create_sales_orders_old
        Customer.create_from_open_orders(self)
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.request {
            xml. ExecuteQueryRq {
              xml.Query "SELECT So.customerId, 
                                So.num, 
                                SoItem.productNum, 
                                SoItem.qtyToFulfill,
                                So.customerContact, 
                                So.billToName,
                                So.billToAddress,
                                so.billToCity,
                                so.billToStateId,
                                so.billToZip,
                                so.billToCountryId,
                                so.shipToName,
                                so.shipToAddress,
                                so.shipToCity,
                                so.shipToStateId,
                                so.shipToZip,
                                so.shipToCountryId,
                                so.carrierId,
                                so.taxRateName,
                                so.priorityId,
                                so.vendorPO,
                                so.salesman,
                                so.shipTermsId,
                                so.paymentTermsId,
                                so.fobPointId,
                                so.note,
                                so.qbClassId,
                                so.locationGroupId,
                                so.url,
                                so.currencyId,
                                so.phone,
                                so.email,
                                so.carrierServiceId,
                                so.dateExpired,
                                so.dateCompleted,
                                so.dateCreated,
                                so.shipToResidential,
                                soItem.typeId,
                                soItem.description,
                                soItem.uomId,
                                soItem.unitPrice,
                                soItem.taxableFlag,
                                soItem.taxId,
                                soItem.note,
                                soItem.qbClassId,
                                soItem.dateScheduledFulfillment,
                                soItem.showItemFlag,
                                soItem.revLevel
                                FROM So 
                                INNER JOIN SoItem 
                                ON So.id = SoItem.soId 
                                WHERE (So.statusId IN (10,20,25,30)) AND (So.customerId NOT IN (328,1779))"
            }
          }
        end
        code, response = Fishbowl::Objects::BaseObject.new.send_request(builder, "ProductGetRs")
        response.xpath("//Row").each do |row|
            row_array=row.try(:content).split(',').map{|x| x.gsub("\"","")}
            customer_fb_id=row_array[0]
            sales_order_num = row_array[1]
            sales_order_params = {}
            sales_order=SalesOrder.find_by_num_and_customer_id(sales_order_num,customer.id)
            if !sales_order 
              sales_order_params[:num]=sales_order_num
              sales_order_params[:customer_id]=customer.id
              sales_order_params[:customer_contact]=row_array[4]
              sales_order_params[:bill_to_name]=row_array[5]
              sales_order_params[:bill_to_address]=row_array[6]
              sales_order_params[:bill_to_city]=row_array[7]
              sales_order_params[:bill_to_state]=row_array[8]
              sales_order_params[:bill_to_zip]=row_array[9]
              sales_order_params[:bill_to_country]=row_array[10]
              sales_order_params[:ship_to_name]=row_array[11]
              sales_order_params[:ship_to_address]=row_array[12]
              sales_order_params[:ship_to_city]=row_array[13]
              sales_order_params[:ship_to_state]=row_array[14]
              sales_order_params[:ship_to_zip]=row_array[15]
              sales_order_params[:ship_to_country]=row_array[16]
              sales_order_params[:carrier_name]=row_array[17]
              sales_order_params[:tax_rate_name]=row_array[18]
              sales_order_params[:priority_id]=row_array[19]
              sales_order_params[:po_num]=row_array[20]
              sales_order_params[:salesman]=row_array[21]
              sales_order_params[:shipping_terms]=row_array[22]
              sales_order_params[:payment_terms]=row_array[23]
              sales_order_params[:fob]=row_array[24]
              sales_order_params[:note]=row_array[25]
              sales_order_params[:quickbooks_class_name]=row_array[26]
              sales_order_params[:location_group_name]=row_array[27]
              sales_order_params[:url]=row_array[28]
              sales_order_params[:price_is_home_currency]=true
              sales_order_params[:phone]=row_array[29]
              sales_order_params[:email]=row_array[30]
              sales_order_params[:carrier_service]=row_array[31]
              sales_order_params[:currency_name]=row_array[32]
              sales_order_params[:currency_rate]=row_array[33]
              sales_order_params[:date_expired]=row_array[34]
              sales_order_params[:fulfillment_date]=row_array[35]
              sales_order_params[:date]=row_array[36]
              sales_order_params[:ship_to_residential]=row_array[37]
              sales_order=SalesOrder.create(sales_order_params )
            end
            sales_order_item_params = {}
            sales_order_item_params[:product_num] = row_array[2]
            sales_order_item_params[:qty_to_fulfill] = row_array[3]
            sales_order_item_params[:sales_order_id] = sales_order.id
            sales_order_item_params[:so_item_type_id]=row_array[39]
            sales_order_item_params[:product_description]=row_array[40]
            sales_order_item_params[:uom]=row_array[41]
            sales_order_item_params[:product_price]=row_array[42]
            sales_order_item_params[:taxable]=row_array[43]
            sales_order_item_params[:tax_code]=row_array[44]
            sales_order_item_params[:note]=row_array[45]
            sales_order_item_params[:quickbooks_class_name]=row_array[46]
            sales_order_item_params[:fulfillment_date]=row_array[47]
            sales_order_item_params[:show_item]=row_array[48]
            sales_order_item_params[:kit_item]=row_array[49]
            sales_order_item_params[:revision_level]=row_array[50]
            SalesOrderItem.create(sales_order_item_params)
        end
    end
end
