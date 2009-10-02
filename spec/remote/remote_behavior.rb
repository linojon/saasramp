#--------------------
# shared behavior
# ensure all gatways have the same api, as expected by the subscription_transaction model

describe "a gateway expected by saasramp", :shared => true do
  # before each assumptions:
  # @gateway  # an active merchant gateway instance
  # @cc       # an active merchant billing credit card instance  
  # @options  # any additional required transaction options
  # @sleep    # seconds to sleep between doing a purchase/refund (can be nil)
  # @validate_via_transaction # like setting validate_via_transaction: in subscription.yml, wont bother testing authorize/void when false
  
  before :each do
    @options ||= {}
    @amount = 995
    @validate_via_transaction ||= true
  end
  
  it "stores customer profile and gets customer key" do
    response = @gateway.store( @cc )
    response.should be_success
  end
  
  it "unstore customer profile" do
    response = @gateway.store( @cc )
    @key = response.token
    response = @gateway.unstore( @key )
    response.should be_success
  end
  
  if @validate_via_transaction
    it "authorizes a charge on credit card (for validation)" do
      response = @gateway.authorize( @amount, @cc )
      response.should be_success
    end
  
    it "void an authorized charge (for validation)" do
      response1 = @gateway.authorize( @amount, @cc )
      response1.should be_success
      response = @gateway.void( response1.authorization )
      response.should be_success
    end
  end

  describe "with key" do
    # re-use the same key for the rest of these
    before :all do
      response = @gateway.store( @cc )
      @key = response.token
    end
    after :all do
      response = @gateway.unstore( @key ) if @key
    end
    
    # TODO
    #it "updates customer profile using customer key"
  
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
    
    if @gateway.respond_to?(:refund)
      it "refund an amount against a prior purchase" do
        @amount = 200 # change amount to avoid "duplicate transaction" error
        response = @gateway.purchase( @amount, @key )
        pp response unless response.success?
        response.should be_success
        @trans_id = response.authorization
        
        # the gateway needs time to process the purchase before we can refund against it
        # according to AuthorizeNet support, thats about every 10 minute in the test environment
        # in production "they would only settle once a day after the merchant defined Transaction Cut Off Time."
        skip = false
        if @sleep
          puts "sleeping #{@sleep} (press enter to skip)"
          if select([STDIN],[],[],seconds)
            puts 'skipped'
            skip = true
          else
            puts 'awake'
          end
        end
        
        unless skip
          response = @gateway.refund( @trans_id, :amount => @amount, :billing_id => @key )
          pp response unless response.success?
          response.should be_success
        end
        # response = @gateway.refund( @trans_id, :amount => @amount )
        # response.should be_success
      end
    end
    
  end
  
end

  
