class AddInventorySyncIdToProducts < ActiveRecord::Migration
  def change
    add_column :products, :inventory_sync_id, :integer, :references => "inventory_syncs", index: true, foreign_key: true
    add_index :products, [:num, :inventory_sync_id]
  end
end
