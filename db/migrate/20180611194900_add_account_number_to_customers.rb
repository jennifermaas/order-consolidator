class AddAccountNumberToCustomers < ActiveRecord::Migration
  def change
    add_column :customers, :account_number, :string
  end
end
