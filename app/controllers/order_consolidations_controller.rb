class OrderConsolidationsController < ApplicationController

  def show
    @order_consolidation = OrderConsolidation.find_by_id params[:id]
  end
end
