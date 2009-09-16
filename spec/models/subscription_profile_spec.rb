require File.dirname(__FILE__) + '/../spec_helper'

describe SubscriptionProfile do
  describe "states" do    
    before :each do
      @profile = SubscriptionProfile.create( :subscription_id => Subscription.new )
    end
    
    it "initially no_info" do
      @profile.should be_no_info # .no_info?
    end
    
    it "authorized" do
      @profile.state = 'no_info'
      @profile.authorized
      @profile.should be_authorized # .authorized?

      @profile.state = 'error'
      @profile.authorized
      @profile.should be_authorized # .authorized?
    end
    
    it "error" do
      @profile.state = 'no_info'
      @profile.error
      @profile.should be_error # .error?

      @profile.state = 'authorized'
      @profile.error
      @profile.should be_error # .error?      
    end
    
    it "remove" do
      @profile.state = 'authorized'
      @profile.remove
      @profile.should be_no_info # .no_info?

      @profile.state = 'error'
      @profile.remove
      @profile.should be_no_info   
    end
  end
  
  describe "credit card" do
    before :each do
      @user = create_subscriber
      @subscription = @user.subscription
      @profile = @subscription.profile
    end
    
    it "profile saves successfully" do
      @profile.credit_card = bogus_credit_card
      @profile.save.should be_true
    end
        
    it "stores card in gateway on save" do
      @profile.credit_card = bogus_credit_card
      SubscriptionTransaction.should_receive(:store).and_return(
        SubscriptionTransaction.new( :success => true )
      )      
      @profile.save.should be_true
    end
    
    it "does not save if card doesnt validate" do
      # bogus gateway skips most validations
      #@profile.credit_card = bogus_credit_card( :number => 'notanumber' )
      @profile.credit_card = bogus_credit_card( :first_name => '' )
      @profile.save.should be_false
    end
    
    it "has credit card validation messages in profile object" do
      @profile.credit_card = bogus_credit_card( :first_name => '' )
      @profile.should_not be_valid
      @profile.credit_card.errors.full_messages.should include('First name cannot be empty')
      #@profile.errors[:credit_card].should == 'must be valid'
      @profile.errors.full_messages.should include('First name cannot be empty')
    end
  
    it "does not save if card fails authorization test" do
      @profile.credit_card = bogus_credit_card( :number => BOGUS_CC_ERROR )
      @profile.save.should_not be_true
      #@profile.errors[:credit_card].should include('failed to store card')
    end
  
    it "keeps the profile name, last 4 digits, etc when saved" do
      @profile.credit_card = bogus_credit_card
      @profile.save.should be_true  
      @profile.card_first_name.should == 'Firstname'    
      @profile.card_last_name.should == 'Lastname'    
      @profile.card_type.should == 'bogus'    
      @profile.card_display_number.should == 'XXXX-XXXX-XXXX-1'
      @profile.card_expires_on.to_s.should == "#{ Time.now.year + 1 }-08-31"
    end
  
    it "get new card with some kept values" do
      @profile.credit_card = bogus_credit_card
      @profile.save.should be_true  
      card = @profile.new_credit_card
      
      card.first_name.should == 'Firstname'
      card.last_name.should == 'Lastname'
      card.type.should == 'bogus'
      
      card.number.should be_blank
      card.month.should be_blank
      card.year.should be_blank
      card.verification_value.should be_blank
    end
    
    it "uses update instead of store if have a profile_key"
  end

end
