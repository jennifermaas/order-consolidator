class AddInventoryValuesToProducts < ActiveRecord::Migration
  def change
    add_column :products, :qty_on_hand, :integer, default: 0
    add_column :products, :qty_committed, :integer, default: 0
    add_column :products, :qty_not_pickable, :integer, default: 0
  end
end
