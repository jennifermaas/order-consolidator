class SalesOrderItem
    attr_accessor :num,:product,:qty_to_fulfill,:uom_id, :xml
    
    def initialize(args)
        @num=args[:num]
        @product=Product.new(num: args[:product_num]) if args[:product_num]
        @qty_to_fulfill=args[:qty_to_fulfill]
        @uom_id=args[:uom_id]
        @xml=args[:xml]
    end
    
    def is_fully_pickable?
        qty_to_fulfill <= product.qty_pickable
    end
    
    def xml_hash
        order_item_xml_hash={}
        order_item_xml_hash["Flag"]="Item"
        order_item_xml_hash["SOItemTypeID"]=xml.xpath("ItemType").inner_html
        order_item_xml_hash["ProductNumber"]=xml.xpath("ProductNumber").inner_html
        order_item_xml_hash["ProductDescription"]=xml.xpath("Description").inner_html
        order_item_xml_hash["ProductQuantity"]=xml.xpath("Quantity").inner_html
        order_item_xml_hash["UOM"]=xml.xpath("UOMCode").inner_html
        order_item_xml_hash["ProductPrice"]=xml.xpath("ProductPrice").inner_html
        order_item_xml_hash["Taxable"]=xml.xpath("Taxable").inner_html
        order_item_xml_hash["TaxCode"]=""
        order_item_xml_hash["Note"]=xml.xpath("Note").inner_html
        order_item_xml_hash["QuickBooksClassName"]=xml.xpath("QuickBooksClassName").inner_html
        order_item_xml_hash["FulfillmentDate"]=DateTime.parse(xml.xpath("DateScheduledFulfillment").inner_html).strftime("%m/%d/%Y")
        order_item_xml_hash["ShowItem"]=xml.xpath("ShowItemFlag").inner_html
        order_item_xml_hash["KitItem"]=""
        order_item_xml_hash["RevisionLevel"]=xml.xpath("RevisionLevel").inner_html
        return order_item_xml_hash
    end
end