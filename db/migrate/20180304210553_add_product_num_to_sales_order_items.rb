class AddProductNumToSalesOrderItems < ActiveRecord::Migration
  def change
    add_column :sales_order_items, :product_num, :string
  end
end
