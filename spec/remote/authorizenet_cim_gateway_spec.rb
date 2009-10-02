require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/remote_behavior'

describe AuthorizeNetCimGateway do
  before :all do
    ActiveMerchant::Billing::Base.mode = :test
    
    gateway_params = {
      :login    => '5Lh6pXSLh2sU',      # API login
      :password => '2c33558GR3mcNeTj',   # API transaction key
      :test => true 
    }
    @gateway = ActiveMerchant::Billing::Base.gateway('authorize_net_cim').new( gateway_params )
    
    cc_params = credit_card_hash( 
      :type               => 'visa',
      :number             => '4007000000027',
      :verification_value => '999'
    )
    @cc = ActiveMerchant::Billing::CreditCard.new( cc_params ) 
    @sleep = 600   
    # disable authorize/void validation (until cim gateway is upgraded)
    @validate_via_transaction = false 
  end

  it_should_behave_like "a gateway expected by saasramp"
  
end
