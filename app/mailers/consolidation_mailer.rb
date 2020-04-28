class ConsolidationMailer < ApplicationMailer
    add_template_helper(ApplicationHelper)
    def report(params)
        @order_consolidation=OrderConsolidation.find_by_id params[:order_consolidation_id]
        @error = params[:error]
        mail(to: 'jennifer@lightintheattic.net,josh@lightintheattic.net,thuy@lightintheattic.net,daniel@lightintheattic.net', subject: 'Order Consolidation Report', from: 'webmaster@lightintheattic.net')
    end
end
