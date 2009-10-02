require File.dirname(__FILE__) + '/../spec_helper'
#require File.dirname(__FILE__) + '/../../../../../config/initializers/active_merchant/bogus'
require File.dirname(__FILE__) + '/remote_behavior'

# Bogus gateway cc numbers
#  1 - successful
#  2 - failed
#  3 - raise exception

describe BogusGateway do
  before :all do
    ActiveMerchant::Billing::Base.mode = :test
    
    gateway_params = {
      :login    => 'user',
      :password => 'secret'
    }
    @gateway = ActiveMerchant::Billing::Base.gateway('bogus').new( gateway_params )
    
    cc_params = credit_card_hash
    @cc = ActiveMerchant::Billing::CreditCard.new( cc_params ) 
    
    @options = {
      :order_id   => generate_unique_id,
      :address    => address_hash
    }
  end
  
  it_should_behave_like "a gateway expected by saasramp"
  
end
