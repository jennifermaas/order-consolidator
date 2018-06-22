class AddHasCommittedToCustomer < ActiveRecord::Migration
  def change
    add_column :customers, :has_committed, :boolean, :default => false
  end
end
