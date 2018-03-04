class ChangeXmlFieldsToText < ActiveRecord::Migration
  def change
    change_column :sales_orders, :xml, :text
    change_column :sales_order_items, :xml, :text
  end
end
