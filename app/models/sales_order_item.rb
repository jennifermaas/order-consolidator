class SalesOrderItem < ActiveRecord::Base
    belongs_to :sales_order
    validates_presence_of :product_num
    validates :qty_to_fulfill, numericality: { greater_than_or_equal_to: 0 }, on: :update
    
    def is_inventory_item?
        (so_item_type_id && so_item_type_id.to_i <=12 ) ? true : false
    end
    
    def customer
        if sales_order.customer
            return sales_order.customer
        elsif sales_order.customer_as_not_pickable
            return sales_order.customer_as_not_pickable
        else
            return sales_order.customer_as_pickable
        end
    end
    
    def qty_pickable
        product = customer.order_consolidation.products.find_by_num(product_num)
        product ? product.qty_pickable : 0
    end
    
    def qty_pickable_from_fb
        product = customer.order_consolidation.products.find_by_num(product_num)
        product ? product.qty_pickable_from_fb : 0
    end

    
    def xml_hash
        order_item_xml_hash={}
        order_item_xml_hash["Flag"]="Item"
        order_item_xml_hash["SOItemTypeID"]=self.so_item_type_id
        order_item_xml_hash["ProductNumber"]=self.product_num
        order_item_xml_hash["ProductDescription"]=""
        order_item_xml_hash["ProductQuantity"]=self.qty_to_fulfill
        order_item_xml_hash["UOM"]=self.uom
        order_item_xml_hash["ProductPrice"]=self.product_price
        order_item_xml_hash["Taxable"]=self.taxable
        order_item_xml_hash["TaxCode"]=self.tax_code
        order_item_xml_hash["Note"]=self.note
        order_item_xml_hash["QuickBooksClassName"]=self.quickbooks_class_name
        order_item_xml_hash["ShowItem"]=self.show_item
        order_item_xml_hash["KitItem"]=self.kit_item    
        order_item_xml_hash["RevisionLevel"]=self.revision_level
        return order_item_xml_hash
    end
end