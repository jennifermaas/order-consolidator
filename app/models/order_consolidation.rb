class OrderConsolidation < ActiveRecord::Base
    before_create :create_inventory
    after_create :create_sales_orders #, :consolidate_orders
    has_many :customers, -> { order(:name) }, dependent: :destroy
    has_many :products

    def decrement_inventory(args)
        product=Product.find_by_num(args[:product_num])
        product.qty_pickable = product.qty_pickable - args[:qty]
        product.save
    end
    
    def self.get_inventory_xml_from_fishbowl
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
        return response
    end
    
    def create_inventory
        response=OrderConsolidation.get_inventory_xml_from_fishbowl
        puts "RESPONSE: #{response.inspect}"
        response.xpath("//Row")[1..-1].each do |row|
            puts "\n***ROW: #{row.inspect}***\n"
            row_array=row.inner_html.split(',').map{|x| x.gsub("\"","")}
            qty_on_hand = row_array[3]
            qty_allocated = row_array[4]
            qty_not_available = row_array[5]
            qty_pickable = qty_on_hand.to_i - qty_allocated.to_i - qty_not_available.to_i
            Product.create num: "#{row_array[0]}", qty_pickable_from_fb: qty_pickable, qty_pickable: qty_pickable, order_consolidation: self
        end
    end
    
    def consolidate_orders
        customers.each do |customer|
            customer.needs_consolidation?
            customer.consolidate_orders if customer.needs_consolidation?
        end
    end
    
    
    def create_sales_orders
        Customer.create_from_open_orders(self)
        Fishbowl::Connection.connect
        Fishbowl::Connection.login
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.request {
            xml. ExecuteQueryRq {
              xml.Query "SELECT So.customerId, So.num, SoItem.productNum, SoItem.qtyToFulfill FROM So INNER JOIN SoItem ON So.id = SoItem.soId WHERE So.statusId IN (10,20,30)"
            }
          }
        end
        code, response = Fishbowl::Objects::BaseObject.new.send_request(builder, "ProductGetRs")
        Fishbowl::Connection.close
        response.xpath("//Row").each do |row|
            row_array=row.inner_html.split(',').map{|x| x.gsub("\"","")}
            customer_fb_id=row_array[0]
            sales_order_num = row_array[1]
            product_num = row_array[2]
            qty_to_fulfill = row_array[3]
            customer=Customer.find_by_fb_id_and_order_consolidation_id(customer_fb_id,self.id) || Customer.create(fb_id: customer_fb_id, order_consolidation: self)
            sales_order=SalesOrder.find_by_num_and_customer_id(sales_order_num,customer.id) || SalesOrder.create(num: sales_order_num, customer: customer )
            SalesOrderItem.create(product_num: product_num,qty_to_fulfill: qty_to_fulfill, sales_order: sales_order)
        end
    end
end
