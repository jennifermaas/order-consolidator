class ChangeOrderConsolidationsInventoryHash < ActiveRecord::Migration
  def change
    rename_column :order_consolidations, :inventory_hash, :inventory
  end
end
