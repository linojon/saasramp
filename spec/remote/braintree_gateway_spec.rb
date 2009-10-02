require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/remote_behavior'

describe BraintreeGateway do
  before :all do
    ActiveMerchant::Billing::Base.mode = :test
    
    gateway_params = {
      :login    => 'demo',
      :password => 'password'
    }
    @gateway = ActiveMerchant::Billing::Base.gateway('braintree').new( gateway_params )
    
    cc_params = credit_card_hash( 
      :type               => 'visa',
      :number             => '4111111111111111'
    )
    @cc = ActiveMerchant::Billing::CreditCard.new( cc_params ) 
    
    # Note, #refund requires using ActiveMerchant HEAD (as of 9/16/2009) and not 1.4.2   
  end

  it_should_behave_like "a gateway expected by saasramp"
  
end
