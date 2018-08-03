class Product < ActiveRecord::Base
  belongs_to :order_consolidation
  belongs_to :inventory_sync
  #validates :qty_pickable, numericality: { greater_than_or_equal_to: 0 }
end
