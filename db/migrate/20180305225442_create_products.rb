class CreateProducts < ActiveRecord::Migration
  def change
    create_table :products do |t|
      t.string :num
      t.integer :qty_pickable_from_fb
      t.integer :qty_pickable
      t.references :order_consolidation, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
