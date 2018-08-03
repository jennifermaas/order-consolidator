class CreateInventorySyncs < ActiveRecord::Migration
  def change
    create_table :inventory_syncs do |t|

      t.timestamps null: false
    end
  end
end
