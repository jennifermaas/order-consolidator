class OrderConsolidation < ActiveRecord::Base
    before_create :create_inventory_hash
    after_create :create_customers#, :consolidate_orders
    has_many :customers, -> { order(:name) }
    serialize :inventory_hash
    
    def create_inventory_hash
        Fishbowl::Connection.connect
        Fishbowl::Connection.login
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.request {
            xml. ExecuteQueryRq {
              xml.Query "SELECT Product.num,QtyInventoryTotals.* FROM QtyInventoryTotals INNER JOIN Part ON QtyInventoryTotals.partId = Part.id INNER JOIN Product ON Part.id = Product.partId WHERE QtyInventoryTotals.LOCATIONGROUPID=1"
            }
          }
        end
        code, response = Fishbowl::Objects::BaseObject.new.send_request(builder, "ProductGetRs")
        Fishbowl::Connection.close
        product_inventory={}
        response.xpath("//Row")[1..-1].each do |row|
            row_array=row.inner_html.split(',').map{|x| x.gsub("\"","")}
            qty_on_hand = row_array[3]
            qty_allocated = row_array[4]
            qty_not_available = row_array[5]
            qty_pickable = qty_on_hand.to_i - qty_allocated.to_i - qty_not_available.to_i
            product_inventory["#{row_array[0]}"] = {qty_pickable: qty_pickable, qty_picked: 0}
        end
        self.inventory_hash=product_inventory
    end
    
    def create_customers
        Customer.create_from_open_orders(self)
    end
    
    def consolidate_orders
        customers.each do |customer|
            customer.create_sales_orders
            customer.needs_consolidation?
            customer.consolidate_orders if customer.needs_consolidation?
        end
    end
end
