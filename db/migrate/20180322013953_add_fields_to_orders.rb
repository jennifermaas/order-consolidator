class AddFieldsToOrders < ActiveRecord::Migration
  def change
    add_column :sales_orders, :customer_contact, :string
    add_column :sales_orders, :bill_to_name, :string
    add_column :sales_orders, :bill_to_address, :string
    add_column :sales_orders, :bill_to_city, :string
    add_column :sales_orders, :bill_to_state, :string
    add_column :sales_orders, :bill_to_zip, :string
    add_column :sales_orders, :bill_to_country, :string
    add_column :sales_orders, :ship_to_name, :string
    add_column :sales_orders, :ship_to_address, :string
    add_column :sales_orders, :ship_to_city, :string
    add_column :sales_orders, :ship_to_state, :string
    add_column :sales_orders, :ship_to_zip, :string
    add_column :sales_orders, :ship_to_country, :string
    add_column :sales_orders, :carrier_name, :string
    add_column :sales_orders, :tax_rate_name, :string
    add_column :sales_orders, :priority_id, :string
    add_column :sales_orders, :po_num, :string
    add_column :sales_orders, :salesman, :string
    add_column :sales_orders, :shipping_terms, :string
    add_column :sales_orders, :payment_terms, :string
    add_column :sales_orders, :fob, :string
    add_column :sales_orders, :note, :text
    add_column :sales_orders, :quickbooks_class_name, :string
    add_column :sales_orders, :location_group_name, :string
    add_column :sales_orders, :url, :string
    add_column :sales_orders, :price_is_home_currency, :string
    add_column :sales_orders, :phone, :string
    add_column :sales_orders, :email, :string
    add_column :sales_orders, :carrier_service, :string
    add_column :sales_orders, :currency_name, :string
    add_column :sales_orders, :currency_rate, :string
    add_column :sales_orders, :date_expired, :datetime
    add_column :sales_orders, :fulfillment_date, :datetime
    add_column :sales_orders, :date, :datetime
    add_column :sales_orders, :ship_to_residential, :boolean
  end
end
