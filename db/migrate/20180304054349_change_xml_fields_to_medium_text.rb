class ChangeXmlFieldsToMediumText < ActiveRecord::Migration
  def change
    change_column :sales_orders, :xml, :text, limit: 16.megabytes - 1
    change_column :sales_order_items, :xml, :text, limit: 16.megabytes - 1
  end
end
