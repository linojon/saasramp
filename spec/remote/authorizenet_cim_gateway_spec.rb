require File.dirname(__FILE__) + '/../spec_helper'

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
  
  describe "with key" do
    # re-use the same key for the rest of these
    before :all do
      response = @gateway.store( @cc )
      @key = response.token
    end
    
    after :all do
      @gateway.unstore( @key ) if @key
    end

    it "update customer profile using customer key"
  
    it "authorize a charge on credit card (for validation)" do
      response = @gateway.authorize( @amount, @key )
      pp response unless response.success?
      response.should be_success
    end

    it "purchase" do
      response = @gateway.purchase( @amount, @key )
      response.should be_success
    end
  
    it "credit back an amount" do
      pending "disabled for Authorized.net because they discourage using it"
      response = @gateway.credit( @amount, @key)
      response.should be_success
    end

    it "voids a charge on credit card (for validation)" do
      @amount = 2500 # change amount to avoid "duplicate transaction" error
      response = @gateway.authorize( @amount, @key )
      pp response unless response.success?
      response.should be_success  
      @trans_id = response.token #params['direct_response']['transaction_id']      
        
      response = @gateway.void( @amount, @trans_id )
      #pp response
      response.should be_success
    end

    it "refunds a charge" do
      #debugger
      @amount = 5000 # change amount to avoid "duplicate transaction" error
      response = @gateway.purchase( @amount, @key  )
      pp response unless response.success?
      response.should be_success
      @trans_id = response.token
      # the gateway needs time to process the purchase before we can refund against it
      # according to AN support, thats about every 10 minute in the test environment
      # in production "they would only settle once a day after the merchant defined Transaction Cut Off Time."
      seconds = 600
      puts "sleeping #{seconds}..."
      sleep seconds
      puts 'awake'
      response = @gateway.refund( @trans_id, :amount => @amount, :billing_id => @key )
      pp response unless response.success?
      response.should be_success
    end
    
  end
end
