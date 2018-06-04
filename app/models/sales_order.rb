class SalesOrder < ActiveRecord::Base
  
    belongs_to :customer
    has_many :sales_order_items, dependent: :destroy
    has_one :customer_as_pickable, class_name: 'Customer', foreign_key: "pickable_order_id", dependent: :destroy
    has_one :customer_as_not_pickable, class_name: 'Customer', foreign_key: "not_pickable_order_id", dependent: :destroy
    
    def order_consolidation
      customer.order_consolidation
    end
    
    def pickability_status
        pickable_count = 0
        not_pickable_count = 0
        mixed_count = 0
        sales_order_items.each do |sales_order_item|
          if sales_order_item.qty_pickable==0
            not_pickable_count +=1
          elsif sales_order_item.qty_to_fulfill <= sales_order_item.qty_pickable
            pickable_count +=1
          else 
            mixed_count+=1
          end
        end
        puts "\nPICKABLE COUNT: #{pickable_count}, NOT PICKABLE COUNT: #{not_pickable_count}, MIXED COUNT: #{mixed_count}\n"
        if (mixed_count > 0) || ((pickable_count>0) && (not_pickable_count>0))
            return 'mixed'
        elsif pickable_count>0
            return 'pickable'
        elsif not_pickable_count > 0
            return 'not_pickable'
        else
            return 'empty'
        end
    end
    
    def void_in_fishbowl
      request=Nokogiri::XML::Builder.new do |xml|
        xml.request {
          xml.VoidSORq {
            xml.SONumber self.num
          }
        }
      end
      code,response=Fishbowl::Objects::BaseObject.new.send_request(request, 'VoidSORs')
      if response.xpath("//VoidSORs/@statusCode").first.value != "1000"
        self.order_consolidation.create_message "Void order failed for num: #{self.num}"
        return false
      else
        return true
      end
    end

    def xml_hash
        # Sales Order Fields
        origin_order_sibling = if self.customer_as_pickable
          customer_as_pickable.sales_orders[0]
        elsif self.customer_as_not_pickable 
          customer_as_not_pickable.sales_orders[0]
        else
          self
        end
        order_xml_hash = {}
        order_xml_hash["Flag"]="SO"
        order_xml_hash["SONum"]=""
        order_xml_hash["Status"]="20"
        order_xml_hash["CustomerName"]=origin_order_sibling.customer.name
        order_xml_hash["CustomerContact"]=origin_order_sibling.customer_contact
        order_xml_hash["BillToName"]=origin_order_sibling.bill_to_name
        order_xml_hash["BillToAddress"]=origin_order_sibling.bill_to_address
        order_xml_hash["BillToCity"]=origin_order_sibling.bill_to_city
        order_xml_hash["BillToState"]=origin_order_sibling.bill_to_state
        order_xml_hash["BillToZip"]=origin_order_sibling.bill_to_zip
        order_xml_hash["BillToCountry"]=origin_order_sibling.bill_to_country
        order_xml_hash["ShipToName"]=origin_order_sibling.ship_to_name
        order_xml_hash["ShipToAddress"]=origin_order_sibling.ship_to_address
        order_xml_hash["ShipToCity"]=origin_order_sibling.ship_to_city
        order_xml_hash["ShipToState"]=origin_order_sibling.ship_to_state
        order_xml_hash["ShipToZip"]=origin_order_sibling.ship_to_zip
        order_xml_hash["ShipToCountry"]=origin_order_sibling.ship_to_country
        order_xml_hash["CarrierName"]=origin_order_sibling.carrier_name
        order_xml_hash["TaxRateName"]=origin_order_sibling.tax_rate_name
        order_xml_hash["PriorityId"]=origin_order_sibling.priority_id
        order_xml_hash["PONum"]=origin_order_sibling.po_num
        order_xml_hash["Date"]=""
        order_xml_hash["Salesman"]=origin_order_sibling.salesman
        order_xml_hash["ShippingTerms"]=origin_order_sibling.shipping_terms
        order_xml_hash["PaymentTerms"]=origin_order_sibling.payment_terms
        order_xml_hash["FOB"]=origin_order_sibling.fob
        order_xml_hash["Note"]=origin_order_sibling.note
        order_xml_hash["QuickBooksClassName"]=origin_order_sibling.quickbooks_class_name
        order_xml_hash["LocationGroupName"]=origin_order_sibling.location_group_name
        order_xml_hash["FulfillmentDate"]=""
        order_xml_hash["URL"]=origin_order_sibling.url
        order_xml_hash["CF-ConsolidationType"] = if self.customer_as_pickable
          'Pickable'
        elsif self.customer_as_not_pickable 
          'Not Pickable'
        else
          ''
        end
        return order_xml_hash
    end
    
end