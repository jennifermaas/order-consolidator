class CreateFishbowlCalls < ActiveRecord::Migration
  def change
    create_table :fishbowl_calls do |t|
      t.integer :customer_id
      t.string :action
      t.string :parameters
      t.boolean :successful

      t.timestamps null: false
    end
  end
end
