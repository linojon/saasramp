ActiveMerchant::Billing::Base.mode = :test if SubscriptionConfig.test

gateway_args = {
  :login    => SubscriptionConfig.login, 
  :password => SubscriptionConfig.password
}.merge( (SubscriptionConfig.gateway_options rescue {}) )

SubscriptionConfig.gateway = ActiveMerchant::Billing::Base.gateway(SubscriptionConfig.gateway_name).new( gateway_args )

SubscriptionConfig.validate_via_transaction = false if SubscriptionConfig.bogus?
