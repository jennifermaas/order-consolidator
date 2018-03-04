class CreateProducts < ActiveRecord::Migration
  def change
    create_table :products do |t|
      t.string :num
      t.integer :qty_on_hand
      t.integer :qty_available
      t.integer :qty_pickable

      t.timestamps null: false
    end
  end
end
