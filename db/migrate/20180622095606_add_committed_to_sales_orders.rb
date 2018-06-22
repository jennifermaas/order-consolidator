class AddCommittedToSalesOrders < ActiveRecord::Migration
  def change
    add_column :sales_orders, :committed, :boolean, :default => false
  end
end
