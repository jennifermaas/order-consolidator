class AddConsolidationInfoToCustomers < ActiveRecord::Migration
  def change
    add_column :customers, :needed_consolidation, :boolean, :default => false
    add_column :customers, :line_items_needed_consolidation, :boolean, :default => false
  end
end
