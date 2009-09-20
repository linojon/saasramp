require File.dirname(__FILE__) + '/../spec_helper'

# reference AM classes with fewer keystrokes
include ActiveMerchant::Billing

# Bogus gateway cc numbers
#  1 - successful
#  2 - failed
#  3 - raise exception

describe SubscriptionTransaction do
  # -------------------------
  describe "attributes" do
    before :each do
      @trans = SubscriptionTransaction.new( :subscription => Subscription.new, :amount_cents => 2500 )
    end
    
    it "has amount in cents" do
      @trans.amount_cents.should == 2500
    end
    it "has amount in Money" do
      @trans.amount.should be_a(Money)
      @trans.amount.format.should == '$25.00'
    end
  end
  # it "has the transaction type"
  # it "keeps the raw response"
  # it "has timestamps"

  # -------------------------
  describe "validate_card" do
    it "successfully validates a credit card" do
      result = SubscriptionTransaction.validate_card(
                bogus_credit_card( :number => '1')
              )
      result.should be_success
      result.action.should == 'validate'
      #SubscriptionConfig.gateway.foo
      result.message.should == BogusGateway::SUCCESS_MESSAGE # ActiveMerchant::Billing::BogusGateway::SUCCESS_MESSAGE
    end
  
    it "fails to validate a bad credit card" do
      result = SubscriptionTransaction.validate_card(
                bogus_credit_card( :number => '2')
              )
      result.should_not be_success
      result.action.should == 'validate'
      result.message.should == BogusGateway::FAILURE_MESSAGE
    end
    
    it "gets exception during transaction" do
      result = SubscriptionTransaction.validate_card(
                bogus_credit_card( :number => '3')
              )
      result.should_not be_success
      result.action.should == 'validate'
      result.message.should == BogusGateway::ERROR_MESSAGE
    end
  end
  
  # -------------------------
  describe "store card" do
    it "successfully stores a credit card" do
      result = SubscriptionTransaction.store(
                bogus_credit_card( :number => '1')
              )
      result.should be_success
      result.action.should == 'store'
      result.reference.should == BogusGateway::AUTHORIZATION
      result.message.should == BogusGateway::SUCCESS_MESSAGE
    end
  
    it "fails to store a bad credit card" do
      result = SubscriptionTransaction.store(
                bogus_credit_card( :number => '2')
              )
      result.should_not be_success
      result.action.should == 'store'
      result.reference.should be_nil      
      result.message.should == BogusGateway::FAILURE_MESSAGE
    end
    
    it "gets exception during store" do
      result = SubscriptionTransaction.store(
                bogus_credit_card( :number => '3')
              )
      result.should_not be_success
      result.action.should == 'store'
      result.reference.should be_nil
      result.message.should == BogusGateway::ERROR_MESSAGE
    end   
  end
  
  # -------------------------
  # TODO
  # describe "update card" do
  #   it "updates card"
  #   it "unstores then stores if gateway doesnt support update"
  # end
  
  # -------------------------
  describe "unstore card" do    
    it "successfully unstores a credit card" do
      profile_key = '1'
      result = SubscriptionTransaction.unstore( profile_key )
      result.should be_success
      result.action.should == 'unstore'
      result.reference.should be_nil
      result.message.should == BogusGateway::SUCCESS_MESSAGE
    end
  
    it "fails to unstore a bad profile key" do
      profile_key = '2'
      result = SubscriptionTransaction.unstore( profile_key )
      result.should_not be_success
      result.action.should == 'unstore'
      result.reference.should be_nil
      result.message.should == BogusGateway::FAILURE_MESSAGE
    end
    
    it "gets exception during store" do
      profile_key = '3'
      result = SubscriptionTransaction.unstore( profile_key )
      result.should_not be_success
      result.action.should == 'unstore'
      result.reference.should be_nil
      result.message.should == BogusGateway::UNSTORE_ERROR_MESSAGE
    end
  end
  
  # -------------------------
  describe "charge amount" do
    before :each do
      @amount = 2500
    end
    
    it "successfully charges amount" do
      profile_key = '1'
      result = SubscriptionTransaction.charge( @amount, profile_key )
      result.should be_success
      result.action.should == 'charge'
      result.amount_cents.should == @amount
      result.message.should == BogusGateway::SUCCESS_MESSAGE
    end

    it "successfully charges amount in Money" do
      @money = Money.new(@amount)
      profile_key = '1'
      result = SubscriptionTransaction.charge( @money, profile_key )
      result.should be_success
      result.action.should == 'charge'
      result.amount_cents.should == @amount
      result.message.should == BogusGateway::SUCCESS_MESSAGE
    end
  
    it "fails to charge" do
      profile_key = '2'
      result = SubscriptionTransaction.charge( @amount, profile_key )
      result.should_not be_success
      result.action.should == 'charge'
      result.amount_cents.should == @amount
      result.message.should == BogusGateway::FAILURE_MESSAGE
    end
    
    it "gets exception during charge" do
      profile_key = '3'
      result = SubscriptionTransaction.charge( @amount, profile_key )
      result.should_not be_success
      result.action.should == 'charge'
      result.amount_cents.should == @amount
      result.message.should == BogusGateway::ERROR_MESSAGE
    end
  end
  
  # -------------------------
  describe "credit amount" do
    before :each do
      @amount = 2500
    end
    
    it "successfully credits amount" do
      profile_key = '1'
      result = SubscriptionTransaction.credit( @amount, profile_key )
      result.should be_success
      result.action.should == 'credit'
      result.amount_cents.should == @amount
      result.message.should == BogusGateway::SUCCESS_MESSAGE
    end

    it "successfully credit amount in Money" do
      @money = Money.new(@amount)
      profile_key = '1'
      result = SubscriptionTransaction.credit( @money, profile_key )
      result.should be_success
      result.action.should == 'credit'
      result.amount_cents.should == @amount
      result.message.should == BogusGateway::SUCCESS_MESSAGE
    end
  
    it "fails to credit" do
      profile_key = '2'
      result = SubscriptionTransaction.credit( @amount, profile_key )
      result.should_not be_success
      result.action.should == 'credit'
      result.amount_cents.should == @amount
      result.message.should == BogusGateway::FAILURE_MESSAGE
    end
    
    it "gets exception during credit" do
      profile_key = '3'
      result = SubscriptionTransaction.credit( @amount, profile_key )
      result.should_not be_success
      result.action.should == 'credit'
      result.amount_cents.should == @amount
      result.message.should == BogusGateway::ERROR_MESSAGE
    end
    
    # TODO
    # describe "as refund" do
    #   it "uses refund when gateway doesnt support credit"
    #   it "finds a recent charge"
    #   it "refunds against that charge"
    # end
  end
end
