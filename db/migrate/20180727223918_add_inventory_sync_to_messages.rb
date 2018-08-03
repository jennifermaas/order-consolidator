class AddInventorySyncToMessages < ActiveRecord::Migration
  def change
        add_column :messages, :inventory_sync_id, :integer, :references => "inventory_syncs", index: true, foreign_key: true
  end
end
