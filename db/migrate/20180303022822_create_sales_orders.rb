class CreateSalesOrders < ActiveRecord::Migration
  def change
    create_table :sales_orders do |t|
      t.string :num
      t.references :customer, index: true, foreign_key: true
      t.string :xml

      t.timestamps null: false
    end
  end
end
