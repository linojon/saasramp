require File.dirname(__FILE__) + '/../spec_helper'

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
    @amount = 995
  end

  it "store customer profile and gets customer key" do
    response = @gateway.store( @cc )
    response.should be_success
  end
  
  it "unstore customer profile" do
    response = @gateway.store( @cc )
    @key = response.token
    response = @gateway.unstore( @key )
    response.should be_success
  end
  
  it "authorize a charge on credit card (for validation)" do
    response = @gateway.authorize( @amount, @cc )
    response.should be_success
  end
  
  it "void an authorized charge (for validation)" do
    response1 = @gateway.authorize( @amount, @cc )
    response1.should be_success
    response = @gateway.void( response1.authorization )
    response.should be_success
  end

  describe "with key" do
    # re-use the same key for the rest of these
    before :all do
      response = @gateway.store( @cc )
      @key = response.token
    end

    it "update customer profile"
  
    it "purchase" do
      response = @gateway.purchase( @amount, @key )
      response.should be_success
    end
  
    if @gateway.respond_to?(:credit)
      it "credit back an amount" do
        response = @gateway.credit( @amount, @key)
        response.should be_success
      end
    end
    
    # Note, these require using ActiveMerchant HEAD (as of 9/16/2009) and not 1.4.2
    if @gateway.respond_to?(:refund)
      it "refund an amount against a prior purchase" do
        response = @gateway.purchase( @amount, @key )
        response.should be_success
        @trans_id = response.authorization

        response = @gateway.refund( @trans_id, :amount => @amount )
        response.should be_success
      end
    end
    
  end
end
