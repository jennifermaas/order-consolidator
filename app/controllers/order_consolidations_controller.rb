class OrderConsolidationsController < ApplicationController

  def show
    @order_consolidation = OrderConsolidation.find_by_id params[:id]
    @show_all = params[:show_all] ? true : false
  end
  
  def index
    @order_consolidations = OrderConsolidation.all.order("id desc")
    @order_consolidation = OrderConsolidation.new
  end
  
  def create
    @order_consolidation = OrderConsolidation.create
    @order_consolidation.delay.run
    redirect_to @order_consolidation
  end
  
end
