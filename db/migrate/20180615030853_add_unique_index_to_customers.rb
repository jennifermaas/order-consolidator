class AddUniqueIndexToCustomers < ActiveRecord::Migration
  def change
     add_index :customers, [:account_number, :order_consolidation_id], unique: true
  end
end
