class InventorySyncMailer < ApplicationMailer
    add_template_helper(ApplicationHelper)
    def report(params)
        @inventory_sync=InventorySync.find_by_id params[:inventory_sync_id]
        @error = params[:error]
        mail(to: 'jennifer@lightintheattic.net', subject: 'Inventory Sync Report', from: 'webmaster@lightintheattic.net')
    end
end
