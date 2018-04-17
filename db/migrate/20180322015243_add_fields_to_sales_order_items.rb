class AddFieldsToSalesOrderItems < ActiveRecord::Migration
  def change
    add_column :sales_order_items, :so_item_type_id, :string
    add_column :sales_order_items, :product_description, :string
    add_column :sales_order_items, :uom, :string
    add_column :sales_order_items, :product_price, :decimal
    add_column :sales_order_items, :taxable, :boolean
    add_column :sales_order_items, :tax_code, :string
    add_column :sales_order_items, :note, :text
    add_column :sales_order_items, :quickbooks_class_name, :string
    add_column :sales_order_items, :fulfillment_date, :datetime
    add_column :sales_order_items, :show_item, :boolean
    add_column :sales_order_items, :kit_item, :boolean
    add_column :sales_order_items, :revision_level, :string
  end
end
