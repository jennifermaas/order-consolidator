class CreateOrderConsolidations < ActiveRecord::Migration
  def change
    create_table :order_consolidations do |t|

      t.timestamps null: false
    end
  end
end
