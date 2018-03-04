class AddInventoryHashToOrderConsolidations < ActiveRecord::Migration
  def change
    add_column :order_consolidations, :inventory_hash, :text, limit: 16.megabytes - 1
  end
end
