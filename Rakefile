# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)

Rails.application.load_tasks

namespace :consolidator do
  task :create, [:path] => :environment do |t, args|
      begin
        @order_consolidation=OrderConsolidation.create
        @order_consolidation.run
        ConsolidationMailer.report(order_consolidation_id: @order_consolidation.id).deliver_now
      rescue => e 
        oc_id = @order_consolidation ? @order_consolidation.id : 'nil'
        ConsolidationMailer.report(error: e,order_consolidation_id: oc_id).deliver_now
      end
  end

end

namespace :inventory_sync do
  task :create, [:path] => :environment do |t, args|
      begin
        @inventory_sync=InventorySync.create
        @inventory_sync.run
        InventorySyncMailer.report(inventory_sync_id: @inventory_sync.id).deliver_now
      rescue => e 
        is_id = @inventory_sync ? @inventory_sync.id : 'nil'
        InventorySyncMailer.report(error: e,inventory_sync: is_id).deliver_now
      end
  end

end