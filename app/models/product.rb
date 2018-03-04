class Product < ActiveRecord::Base
    
    attr_accessor :quantities
    validates_presence_of :num, :qty_pickable
    validates_numericality_of :qty_pickable
    before_validation :get_qty_pickable
    has_many :sales_order_items
    
    def self.get_inventory_xml_from_fishbowl(num)
        Fishbowl::Connection.connect
        Fishbowl::Connection.login
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.request {
            xml. InvQtyRq {
              xml.PartNum num
            }
          }
        end
        code, response = Fishbowl::Objects::BaseObject.new.send_request(builder, "ProductGetRs")
        puts "RESPONSE: #{response}"
        Fishbowl::Connection.close
        return response
    end

    def get_qty_pickable
        if !self.qty_pickable
            response=Product.get_inventory_xml_from_fishbowl(num)
            self.qty_pickable =0
            response.xpath("FbiXml//InvQty").each do |row|
                self.qty_pickable+=row.at_xpath('QtyAvailable').text.to_i
                puts "qty_pickable: #{self.qty_pickable}"
            end
        end
    end
end