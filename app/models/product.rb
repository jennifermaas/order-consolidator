class Product
    
    attr_accessor :num,:qty_on_hand,:qty_available,:qty_committed, :qty_pickable
    
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
    
    def initialize(args)
        @num=args[:num]
        if args[:quantities]
            qty_on_hand = args[:quantities][:qty_on_hand]
            qty_available = args[:quantities][:qty_available]
            qty_committed = args[:quantities][:qty_committed]
        else
          quantities=Rails.cache.fetch("#{num}/quantities", expires_in: 1.seconds) do
                response=Product.get_inventory_xml_from_fishbowl(num)
                qty_on_hand =0
                qty_available =0
                qty_committed =0
                response.xpath("FbiXml//InvQty").each do |row|
                    qty_on_hand+=row.at_xpath('QtyOnHand').text.to_i
                    qty_available+=row.at_xpath('QtyAvailable').text.to_i
                    qty_committed+=row.at_xpath('QtyCommitted').text.to_i
                end
                {:on_hand => qty_on_hand,:available => qty_available,:committed => qty_committed }
            end
        end
        @qty_on_hand= qty_on_hand
        @qty_pickable=qty_available
        @qty_committed=qty_committed
    end
end