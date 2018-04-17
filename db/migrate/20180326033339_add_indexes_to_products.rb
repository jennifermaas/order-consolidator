class AddIndexesToProducts < ActiveRecord::Migration
  def change
    add_index :products, :num
    add_index :products, [:num, :order_consolidation_id]
  end
end
