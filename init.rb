require 'saasramp'
require 'saasramp/acts_as_subscriber'

# load configuration settings
SubscriptionConfig.load

# initialize AM test mode
ActiveMerchant::Billing::Base.mode = :test if SubscriptionConfig.test

# create gateway instance
gateway_args = {
  :login    => SubscriptionConfig.login, 
  :password => SubscriptionConfig.password
}.merge( (SubscriptionConfig.gateway_options rescue {}) )
SubscriptionConfig.gateway = ActiveMerchant::Billing::Base.gateway(SubscriptionConfig.gateway_name).new( gateway_args )

# adjust other configuration
SubscriptionConfig.validate_via_transaction = false if SubscriptionConfig.bogus?

# enable acts_as_subscriber
ActiveRecord::Base.class_eval do
  include Saasramp::Acts::Subscriber
end
