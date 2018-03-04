class OrderConsolidationsController < ApplicationController
  def index
    @customers=Customer.create_from_open_orders
  end

  def show
    @order_consolidation = OrderConsolidation.find_by_id params[:id]
  end
end
