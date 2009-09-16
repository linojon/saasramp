begin
  require File.dirname(__FILE__) + '/../../../../spec/spec_helper'
rescue LoadError
  puts "You need to install rspec in your base app"
  exit
end

plugin_spec_dir = File.dirname(__FILE__)
ActiveRecord::Base.logger = Logger.new(plugin_spec_dir + "/debug.log")

# reference AM classes with fewer keystrokes
include ActiveMerchant::Billing

# simple factories
def create_subscription_plans
  @free  = SubscriptionPlan.create( :name => 'free',  :rate_cents => 0 )
  @basic = SubscriptionPlan.create( :name => 'basic', :rate_cents => 1000 )
  @pro   = SubscriptionPlan.create( :name => 'pro',   :rate_cents => 2500 )
end

def create_subscription( options = {})
  params = {
    :subscriber_id    => 1,
    :subscriber_type  => 'User'
  }.merge( options )
  Subscription.create( params )
end

def create_subscriber( options = {})
  params = {
    :username   => 'subscriber',
    :password   => 'secret',
    :password_confirmation => 'secret',
    :subscription_plan => @basic
  }.merge( options )
  params[:email] ||= params[:username] + '@example.com'
  user = User.create( params )
end

BOGUS_CC_OK = '1'
BOGUS_CC_EXCEPTION = '2'
BOGUS_CC_ERROR = '3'
def credit_card_hash(options = {}) 
  { :number     => BOGUS_CC_OK, 
    :first_name => 'Firstname', 
    :last_name  => 'Lastname', 
    :month      => '8', 
    :year       => "#{ Time.now.year + 1 }", 
    :verification_value => '123', 
    :type       => 'bogus' 
  }.merge(options) 
end 

def bogus_credit_card(options = {}) 
  ActiveMerchant::Billing::CreditCard.new( credit_card_hash(options) ) 
end 

def address_hash(options = {})
  { 
    :name     => 'Jim Smith',
    :address1 => '1234 My Street',
    :address2 => 'Apt 1',
    :company  => 'Widgets Inc',
    :city     => 'Ottawa',
    :state    => 'ON',
    :zip      => 'K1C2N6',
    :country  => 'CA',
    :phone    => '(555)555-5555',
    :fax      => '(555)555-6666'
  }.update(options)
end

def generate_unique_id
  ActiveMerchant::Utils::generate_unique_id
end

#

#--------------------
# mailer

def mailer_setup
  ActionMailer::Base.delivery_method = :test
  ActionMailer::Base.perform_deliveries = true
  ActionMailer::Base.deliveries = []
end

# and per Ben Mabey email Oct 19,07
def empty_the_mailer!
  ActionMailer::Base.deliveries=[]
end

def mailer_should_deliver(amount_to_send=1)
  lambda { yield}.should change(ActionMailer::Base.deliveries, 
:size).by(amount_to_send)
end

# can say email_sent(-1) for last; email_sent(-2) for 2nd to last
def email_sent(index=0)
  ActionMailer::Base.deliveries[index]
end

def last_email_sent(index=-1)
 ActionMailer::Base.deliveries[index]
end

def number_of_emails_sent
  ActionMailer::Base.deliveries.size
end
  
