# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20180615030853) do

  create_table "customers", force: :cascade do |t|
    t.integer  "fb_id",                           limit: 4
    t.string   "name",                            limit: 255
    t.datetime "created_at",                                                  null: false
    t.datetime "updated_at",                                                  null: false
    t.integer  "pickable_order_id",               limit: 4
    t.integer  "not_pickable_order_id",           limit: 4
    t.integer  "order_consolidation_id",          limit: 4
    t.boolean  "needed_consolidation",                        default: false
    t.boolean  "line_items_needed_consolidation",             default: false
    t.string   "account_number",                  limit: 255
  end

  add_index "customers", ["account_number", "order_consolidation_id"], name: "index_customers_on_account_number_and_order_consolidation_id", unique: true, using: :btree

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer  "priority",   limit: 4,     default: 0, null: false
    t.integer  "attempts",   limit: 4,     default: 0, null: false
    t.text     "handler",    limit: 65535,             null: false
    t.text     "last_error", limit: 65535
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by",  limit: 255
    t.string   "queue",      limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "delayed_jobs", ["priority", "run_at"], name: "delayed_jobs_priority", using: :btree

  create_table "fishbowl_calls", force: :cascade do |t|
    t.integer  "customer_id", limit: 4
    t.string   "action",      limit: 255
    t.string   "parameters",  limit: 255
    t.boolean  "successful"
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

  create_table "messages", force: :cascade do |t|
    t.integer  "order_consolidation_id", limit: 4
    t.text     "body",                   limit: 65535
    t.datetime "created_at",                           null: false
    t.datetime "updated_at",                           null: false
  end

  add_index "messages", ["order_consolidation_id"], name: "index_messages_on_order_consolidation_id", using: :btree

  create_table "order_consolidations", force: :cascade do |t|
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
    t.text     "inventory",  limit: 16777215
  end

  create_table "products", force: :cascade do |t|
    t.string   "num",                    limit: 255
    t.integer  "qty_pickable_from_fb",   limit: 4,   default: 0
    t.integer  "qty_pickable",           limit: 4,   default: 0
    t.integer  "order_consolidation_id", limit: 4
    t.datetime "created_at",                                     null: false
    t.datetime "updated_at",                                     null: false
    t.integer  "qty_on_hand",            limit: 4,   default: 0
    t.integer  "qty_committed",          limit: 4,   default: 0
    t.integer  "qty_not_pickable",       limit: 4,   default: 0
  end

  add_index "products", ["num", "order_consolidation_id"], name: "index_products_on_num_and_order_consolidation_id", using: :btree
  add_index "products", ["num"], name: "index_products_on_num", using: :btree
  add_index "products", ["order_consolidation_id"], name: "index_products_on_order_consolidation_id", using: :btree

  create_table "sales_order_items", force: :cascade do |t|
    t.string   "num",                   limit: 255
    t.integer  "product_id",            limit: 4
    t.integer  "sales_order_id",        limit: 4
    t.integer  "qty_to_fulfill",        limit: 4
    t.text     "xml",                   limit: 16777215
    t.string   "uom_id",                limit: 255
    t.datetime "created_at",                                            null: false
    t.datetime "updated_at",                                            null: false
    t.string   "product_num",           limit: 255
    t.string   "so_item_type_id",       limit: 255
    t.string   "product_description",   limit: 255
    t.string   "uom",                   limit: 255
    t.decimal  "product_price",                          precision: 10
    t.boolean  "taxable"
    t.string   "tax_code",              limit: 255
    t.text     "note",                  limit: 65535
    t.string   "quickbooks_class_name", limit: 255
    t.datetime "fulfillment_date"
    t.boolean  "show_item"
    t.boolean  "kit_item"
    t.string   "revision_level",        limit: 255
  end

  add_index "sales_order_items", ["product_id"], name: "index_sales_order_items_on_product_id", using: :btree
  add_index "sales_order_items", ["sales_order_id"], name: "index_sales_order_items_on_sales_order_id", using: :btree

  create_table "sales_orders", force: :cascade do |t|
    t.string   "num",                    limit: 255
    t.integer  "customer_id",            limit: 4
    t.text     "xml",                    limit: 16777215
    t.datetime "created_at",                              null: false
    t.datetime "updated_at",                              null: false
    t.string   "customer_contact",       limit: 255
    t.string   "bill_to_name",           limit: 255
    t.string   "bill_to_address",        limit: 255
    t.string   "bill_to_city",           limit: 255
    t.string   "bill_to_state",          limit: 255
    t.string   "bill_to_zip",            limit: 255
    t.string   "bill_to_country",        limit: 255
    t.string   "ship_to_name",           limit: 255
    t.string   "ship_to_address",        limit: 255
    t.string   "ship_to_city",           limit: 255
    t.string   "ship_to_state",          limit: 255
    t.string   "ship_to_zip",            limit: 255
    t.string   "ship_to_country",        limit: 255
    t.string   "carrier_name",           limit: 255
    t.string   "tax_rate_name",          limit: 255
    t.string   "priority_id",            limit: 255
    t.string   "po_num",                 limit: 255
    t.string   "salesman",               limit: 255
    t.string   "shipping_terms",         limit: 255
    t.string   "payment_terms",          limit: 255
    t.string   "fob",                    limit: 255
    t.text     "note",                   limit: 65535
    t.string   "quickbooks_class_name",  limit: 255
    t.string   "location_group_name",    limit: 255
    t.string   "url",                    limit: 255
    t.string   "price_is_home_currency", limit: 255
    t.string   "phone",                  limit: 255
    t.string   "email",                  limit: 255
    t.string   "carrier_service",        limit: 255
    t.string   "currency_name",          limit: 255
    t.string   "currency_rate",          limit: 255
    t.datetime "date_expired"
    t.datetime "fulfillment_date"
    t.datetime "date"
    t.boolean  "ship_to_residential"
  end

  add_index "sales_orders", ["customer_id"], name: "index_sales_orders_on_customer_id", using: :btree

  add_foreign_key "messages", "order_consolidations"
  add_foreign_key "products", "order_consolidations"
  add_foreign_key "sales_order_items", "products"
  add_foreign_key "sales_order_items", "sales_orders"
  add_foreign_key "sales_orders", "customers"
end
