class CreateSubscriptionEtc < ActiveRecord::Migration
  def self.up
    create_table :subscription_plans, :force => true do |t|
      t.string  :name,                    :null => false
      t.integer :rate_cents,              :default => 0
      t.integer :interval,                :default => 1
      t.timestamps
      
      # add app-specific resource limitations, e.g.
      # t.integer :max_users
      # t.integer :max_memory
      # t.integer :telephone_support
      # NOTE: Should also add to subcriptions table if you want to change settings per account 
      
    end
    
    create_table :subscriptions, :force => true do |t|
      t.integer :subscriber_id,           :null => false
      t.string  :subscriber_type,         :null => false      
      t.integer :plan_id
      t.string  :state
      t.date    :next_renewal_on
      t.integer :warning_level
      t.integer :balance_cents,           :default => 0
      t.timestamps
    end
    
    create_table :subscription_profiles, :force => true do |t|
      t.integer :subscription_id
      t.string  :state
      t.string  :profile_key,             :null => true
      t.string  :card_first_name
      t.string  :card_last_name
      t.string  :card_type
      t.string  :card_display_number
      t.date    :card_expires_on
      # could also add address columns if required by your gateway
      t.timestamps
    end
    
    create_table :subscription_transactions, :force => true do |t|
      t.integer :subscription_id,         :null => false
      t.integer :amount_cents
      t.boolean :success
      t.string  :reference
      t.string  :message
      t.string  :action
      t.text    :params
      t.boolean :test
      t.timestamps
    end
    
    # indexes
    add_index :subscriptions, :subscriber_id
    add_index :subscriptions, :subscriber_type
    add_index :subscriptions, :state
    add_index :subscriptions, :next_renewal_on
    
  end

  def self.down
    drop_table :subscription_profiles
    drop_table :subscription_transactions
    drop_table :subscriptions
    drop_table :subscription_plans
  end
end
