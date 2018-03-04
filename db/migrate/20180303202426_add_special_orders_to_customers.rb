class AddSpecialOrdersToCustomers < ActiveRecord::Migration
  def change
    add_column  :customers, :pickable_order_id, :integer
    add_column :customers, :not_pickable_order_id, :integer
    add_column :customers, :order_consolidation_id, :integer
  end
end
