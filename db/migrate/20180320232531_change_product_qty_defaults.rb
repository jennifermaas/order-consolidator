class ChangeProductQtyDefaults < ActiveRecord::Migration
  def change
    change_column_default :products, :qty_pickable, 0
    change_column_default :products, :qty_pickable_from_fb, 0
  end
end
