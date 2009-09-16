require File.dirname(__FILE__) + '/../spec_helper'
#require File.dirname(__FILE__) + '/../../../../../config/initializers/active_merchant/bogus'
# having a spec for Bogus gateway is kind of silly but consider it a template for gateway specs
# to ensure gateways have the api expected by saasramp

# Bogus gateway cc numbers
#  1 - successful
#  2 - failed
#  3 - raise exception

describe BogusGateway do
  before :each do
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
    @amount = 995
  end
  
  it "stores customer profile and gets customer key" do
    response = @gateway.store( @cc )
    response.should be_success
  end
  
  it "authorizes a charge on credit card (for validation)" do
    response = @gateway.authorize( @amount, @cc )
    response.should be_success
  end

  describe "with key" do
    before :each do
      @key = '1' #ActiveMerchant::Billing::BogusGateway::AUTHORIZATION
    end
    
    #it "updates customer profile using customer key"
  
    describe "unstore" do
      it "unstores customer profile" do
        response = @gateway.unstore( @key )
        response.should be_success
      end
    end 
  
    it "purchases" do
      response = @gateway.purchase( @amount, @key )
      response.should be_success
    end
  
    it "credits back an amount" do
      trans_id = '1'
      response = @gateway.credit( @amount, trans_id )
      response.should be_success
    end
  end
end
