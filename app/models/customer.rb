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
    
    def create_sales_orders
        builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
            xml.request {
              xml.GetSOListRq {
                xml.Status 'All Open'
                xml.LocationGroupName 'LITA'
                xml.AccountNumber self.account_number
                xml.CustomerName self.name
              }
            }
          end
          code, response = Fishbowl::Objects::BaseObject.new.send_request(builder, "ProductGetRs")
          sales_order_params = {}
          response.xpath("FbiXml//SalesOrder").each do |sales_order_xml|
            unless (sales_order_xml.xpath("PriorityId").inner_html[0]=="5") || (sales_order_xml.xpath("Number").inner_html[0]=="G") || (sales_order_xml.xpath("Status").inner_html=="10") || (sales_order_xml.xpath("Number").inner_html[0]=="R") || (sales_order_xml.xpath("Number").inner_html[0]=="@")
              sales_order_params["num"]=sales_order_xml.at_xpath("Number").try(:content)
              sales_order_params["customer_id"]=self.id
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
              xml.Query "select DISTINCT(customer.id),customer.name, customer.number
                                FROM so inner join customer on so.customerId=customer.id  
                                WHERE So.statusId IN (20,25) 
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
                                  AND NOT (customer.name LIKE '%Outside%')
                                  AND NOT (customer.name LIKE '%SRD%')
                                  AND NOT (customer.name LIKE '%Border%')
                                  AND NOT (customer.name LIKE '%Southbound%')
                                  AND NOT (customer.name LIKE '%Cobraside%')
                                  AND NOT (customer.name LIKE '%Tsunami%')"
            }
          }
        end
        code, response = Fishbowl::Objects::BaseObject.new.send_request(builder, "ProductGetRs")
        customers=[]
        response.xpath("//Row")[1..-1].each do |row|
            row_array=row.content.parse_csv
            customers<< Customer.create(fb_id: row_array[0], name: row_array[1], account_number: row_array[2], order_consolidation: order_consolidation)
        end
        #
        return customers
    end
    
end