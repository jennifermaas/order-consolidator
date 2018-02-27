class SalesOrder
  
    attr_accessor :num,:sales_order_items,:customer_id,:customer_name :xml
   
    #def self.find_by_id(param)
    #    Fishbowl::Connection.connect
    #    Fishbowl::Connection.login
    #    resp=Fishbowl::Requests.load_sales_order(param);
    #    SalesOrder.new xml_response: resp
    #    Fishbowl::Connecton.close
    #end
    
    def pickability_status
        pickable_count = sales_order_items.find_all{|x| x.is_fully_pickable?}.count
        not_pickable_count = sales_order_items.find_all{|x| !x.is_fully_pickable?}.count
        if (pickable_count>0) && (not_pickable_count>0)
            return 'mixed'
        elsif pickable_count>0
            return 'pickable'
        elsif not_pickable_count > 0
            return 'not_pickable'
        else
            return 'empty'
        end
    end
    
    # Finds open issued orders
    def self.find_open_orders()
        Fishbowl::Connection.connect
        Fishbowl::Connection.login
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.request {
            xml. GetSOListRq {
              xml.Status 'All Open'
            }
          }
        end
        code, response = Fishbowl::Objects::BaseObject.new.send_request(builder, "ProductGetRs")
        Fishbowl::Connection.close
        sales_orders=[]
        response.xpath("FbiXml//SalesOrder").each do |sales_order_xml|
            num=sales_order_xml.xpath("Number").inner_html
            customer_id=sales_order_xml.xpath("CustomerID").inner_html
            customer_name=sales_order_xml.xpath("CustomerName").inner_html
            sales_order = SalesOrder.new(num: num, customer_id: customer_id,xml: sales_order_xml, customer_name: customer_name )
            sales_order_xml.xpath("Items//SalesOrderItem").each do |sales_order_item_xml|
                num=sales_order_item_xml.xpath("ID").inner_html
                product_num=sales_order_item_xml.xpath("ProductNumber").inner_html
                qty_to_fulfill=sales_order_item_xml.xpath("Quantity").inner_html
                sales_order_item=SalesOrderItem.new(num: num,product_num: product_num,qty_to_fulfill: qty_to_fulfill, xml: sales_order_item_xml)
                sales_order.sales_order_items << sales_order_item
            end
            sales_orders << sales_order
        end
        return sales_orders 
    end
    
    
    def initialize(args)
        @num=args[:num]
        @customer_id=args[:customer_id]
        @sales_order_items = []
        @xml=args[:xml]
    end
    
    def xml_builder
        # Sales Order Fields
        order_xml_hash = {}
        order_xml_hash["Flag"]="SO"
        order_xml_hash["SONum"]=""
        order_xml_hash["Status"]="20"
        order_xml_hash["CustomerName"]=xml.xpath("CustomerName").inner_html
        order_xml_hash["CustomerContact"]=xml.xpath("CustomerContact").inner_html
        order_xml_hash["BillToName"]=xml.xpath("BillTo//Name").inner_html
        order_xml_hash["BillToAddress"]=xml.xpath("BillTo//AddressField").inner_html
        order_xml_hash["BillToCity"]=xml.xpath("BillTo//City").inner_html
        order_xml_hash["BillToState"]=xml.xpath("BillTo//State").inner_html
        order_xml_hash["BillToZip"]=xml.xpath("BillTo//Zip").inner_html
        order_xml_hash["BillToCountry"]=xml.xpath("BillTo//Country").inner_html
        order_xml_hash["ShipToName"]=xml.xpath("Ship//Name").inner_html
        order_xml_hash["ShipToAddress"]=xml.xpath("Ship//AddressField").inner_html
        order_xml_hash["ShipToCity"]=xml.xpath("Ship//City").inner_html
        order_xml_hash["ShipToState"]=xml.xpath("Ship//State").inner_html
        order_xml_hash["ShipToZip"]=xml.xpath("Ship//Zip").inner_html
        order_xml_hash["ShipToCountry"]=xml.xpath("Ship//Country").inner_html
        order_xml_hash["ShipToResidential"]
        order_xml_hash["CarrierName"]=xml.xpath("Carrier").inner_html
        order_xml_hash["TaxRateName"]=xml.xpath("TaxRateName").inner_html
        order_xml_hash["PriorityId"]=xml.xpath("PriorityId").inner_html
        order_xml_hash["PONum"]=xml.xpath("PoNum").inner_html
        order_xml_hash["Date"]=""
        order_xml_hash["Salesman"]=xml.xpath("Salesman").inner_html
        order_xml_hash["ShippingTerms"]=xml.xpath("ShippingTerms").inner_html
        order_xml_hash["PaymentTerms"]=xml.xpath("PaymentTerms").inner_html
        order_xml_hash["FOB"]=xml.xpath("FOB").inner_html
        order_xml_hash["Note"]=xml.xpath("Note").inner_html
        order_xml_hash["QuickBooksClassName"]=xml.xpath("QuickBooksClassName").inner_html
        order_xml_hash["LocationGroupName"]=xml.xpath("LocationGroup").inner_html
        order_xml_hash["FulfillmentDate"]=""
        order_xml_hash["URL"]=xml.xpath("URL").inner_html
        order_xml_hash["CarrierService"]=""
        order_xml_hash["CurrencyName"]=""
        order_xml_hash["CurrencyRate"]=""
        order_xml_hash["PriceIsHomeCurrency"]=xml.xpath("PriceIsHomeCurrency").inner_html
        order_xml_hash["DateExpired"]=""
        order_xml_hash["Phone"]=""
        order_xml_hash["Email"]=""
        builder = Nokogiri::XML::Builder.new do |xml|
              xml.request {
                xml. ImportRq {
                  xml.Type 'ImportSalesOrder'
                  xml.Rows{
                      xml.Row order_xml_hash.keys.map{|x| "\"#{x}\""}.join(",")
                      xml.Row sales_order_items[0].xml_hash.keys.map{|x| "\"#{x}\""}.join(",")
                      xml.Row order_xml_hash.values.map{|x| "\"#{x}\""}.join(",")
                      sales_order_items.each do |sales_order_item|
                        xml.Row sales_order_item.xml_hash.values.map{|x| "\"#{x}\""}.join(",")
                      end
                  }
                }
              }
        end
    end
    
end