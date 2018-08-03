class Message < ActiveRecord::Base
    belongs_to :order_consolidation
    belongs_to :inventory_sync
end
