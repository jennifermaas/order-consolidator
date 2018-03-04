class CreateSalesOrderItems < ActiveRecord::Migration
  def change
    create_table :sales_order_items do |t|
      t.string :num
      t.references :product, index: true, foreign_key: true
      t.references :sales_order, index: true, foreign_key: true
      t.integer :qty_to_fulfill
      t.string :xml
      t.string :uom_id

      t.timestamps null: false
    end
  end
end
