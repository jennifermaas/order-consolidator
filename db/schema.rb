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

ActiveRecord::Schema.define(version: 20180304205252) do

  create_table "customers", force: :cascade do |t|
    t.integer  "fb_id",                  limit: 4
    t.string   "name",                   limit: 255
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
    t.integer  "pickable_order_id",      limit: 4
    t.integer  "not_pickable_order_id",  limit: 4
    t.integer  "order_consolidation_id", limit: 4
  end

  add_index "customers", ["pickable_order_id"], name: "index_customers_on_pickable_order_id", using: :btree

  create_table "fishbowl_calls", force: :cascade do |t|
    t.integer  "customer_id", limit: 4
    t.string   "action",      limit: 255
    t.string   "parameters",  limit: 255
    t.boolean  "successful"
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

  create_table "order_consolidations", force: :cascade do |t|
    t.datetime "created_at",                      null: false
    t.datetime "updated_at",                      null: false
    t.text     "inventory_hash", limit: 16777215
  end

  create_table "products", force: :cascade do |t|
    t.string   "num",           limit: 255
    t.integer  "qty_on_hand",   limit: 4
    t.integer  "qty_available", limit: 4
    t.integer  "qty_pickable",  limit: 4
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
  end

  create_table "sales_order_items", force: :cascade do |t|
    t.string   "num",            limit: 255
    t.integer  "product_id",     limit: 4
    t.integer  "sales_order_id", limit: 4
    t.integer  "qty_to_fulfill", limit: 4
    t.text     "xml",            limit: 16777215
    t.string   "uom_id",         limit: 255
    t.datetime "created_at",                      null: false
    t.datetime "updated_at",                      null: false
  end

  add_index "sales_order_items", ["product_id"], name: "index_sales_order_items_on_product_id", using: :btree
  add_index "sales_order_items", ["sales_order_id"], name: "index_sales_order_items_on_sales_order_id", using: :btree

  create_table "sales_orders", force: :cascade do |t|
    t.string   "num",         limit: 255
    t.integer  "customer_id", limit: 4
    t.text     "xml",         limit: 16777215
    t.datetime "created_at",                   null: false
    t.datetime "updated_at",                   null: false
  end

  add_index "sales_orders", ["customer_id"], name: "index_sales_orders_on_customer_id", using: :btree

  add_foreign_key "sales_order_items", "products"
  add_foreign_key "sales_order_items", "sales_orders"
  add_foreign_key "sales_orders", "customers"
end
