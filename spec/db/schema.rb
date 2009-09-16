ActiveRecord::Schema.define(:version => 1) do

  create_table "subscription_plans", :force => true do |t|
    t.string   "name",                            :null => false
    t.integer  "rate_cents",       :default => 0
    t.integer  "interval",         :default => 1
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "subscription_profiles", :force => true do |t|
    t.integer  "subscription_id"
    t.string   "state"
    t.string   "profile_key"
    t.string   "card_first_name"
    t.string   "card_last_name"
    t.string   "card_type"
    t.string   "card_display_number"
    t.date     "card_expires_on"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "subscription_transactions", :force => true do |t|
    t.integer  "subscription_id", :null => false
    t.integer  "amount_cents"
    t.boolean  "success"
    t.string   "reference"
    t.string   "message"
    t.string   "action"
    t.text     "params"
    t.boolean  "test"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "subscriptions", :force => true do |t|
    t.integer  "subscriber_id",                   :null => false
    t.string   "subscriber_type",                 :null => false
    t.integer  "plan_id"
    t.string   "state"
    t.date     "next_renewal_on"
    t.integer  "warning_level"
    t.integer  "balance_cents",    :default => 0
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", :force => true do |t|
    t.string   "username"
    t.string   "email"
  end

end
