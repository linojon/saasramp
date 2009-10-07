require File.dirname(__FILE__) + '/../spec_helper'

describe Subscription do
  # -------------------------
  describe "create with free plan" do
    before :each do
      @plan = SubscriptionPlan.create( :name => 'freebee', :rate_cents => 0)
      @subscription = create_subscription( :plan => @plan )
    end

    it "is free" do
      @subscription.should be_free
    end
    
    it "has nil renewal" do
      @subscription.next_renewal_on.should be_nil
    end    
    
  end
  
  describe "create with paid plan and trial period" do
    before :each do
      SubscriptionConfig.trial_period = 30
      @plan = SubscriptionPlan.create( :name => 'basic', :rate_cents => 1000)
      @subscription = create_subscription( :plan => @plan )
    end
    
    it "is in trial" do
      @subscription.should be_trial
    end
    
    it "sets renewal to end of trial" do
      @subscription.next_renewal_on.should == (Time.zone.today + 30.days).to_date
    end    
  end
  
  describe "create with paid plan and no trial" do
    before :each do
      SubscriptionConfig.trial_period = 0
      @plan = SubscriptionPlan.create( :name => 'basic', :rate_cents => 1000, :interval => 3)
      @subscription = create_subscription( :plan => @plan )
    end
    
    it "is active" do
      @subscription.should be_active
    end
    it "sets renewal to end of interval" do
      @subscription.next_renewal_on.should == (Time.zone.today + 3.months).to_date
    end    
  end
  
  # -------------------------
  describe "renew" do
    before :each do
      SubscriptionConfig.trial_period = 0
      SubscriptionTransaction.stub!(:charge).and_return(SubscriptionTransaction.new(:success => true))
      @plan = SubscriptionPlan.create( :name => 'basic', :rate_cents => 1000, :interval => 1)      
      @subscription = create_subscription( :plan => @plan )
      @subscription.profile.state = 'authorized'
      @subscription.profile.profile_key = '1'
      @today = Time.zone.today
      @subscription.next_renewal_on = @today
      @subscription.state = 'active'
      @subscription.should be_due
    end
    
    it "and_return true when successful" do
      @subscription.renew.should be_true
    end
    
    it "wont renew unless due (and_return nil)" do   
      @subscription.next_renewal_on = @today + 1.day
      @subscription.renew.should be_nil
      @subscription.next_renewal_on.should == (@today + 1.day)    
    end
    
    it "charges credit card the current plan rate" do
      SubscriptionTransaction.should_receive(:charge).with(Money.new(1000), anything).and_return( SubscriptionTransaction.new(:success => true) )
      @subscription.renew      
    end
    
    it "sets state to active if charge transaction success" do
      @subscription.state = 'past_due'
      @subscription.renew
      @subscription.should be_active
    end
    
    it "updates next renewal to one month from when subscription ran out if charge transaction success" do
      # assumes plan interval is one month
      @subscription.renew
      @subscription.next_renewal_on.should == (@today + 1.month)
    end
    
    describe 'transaction fails' do
      before :each do
        SubscriptionTransaction.stub!(:charge).and_return(SubscriptionTransaction.new(:success => false))
      end
      it "fails if charge transaction fails (and_return false)" do
        @subscription.renew.should be_false
      end
    
      it "sets past_due state if charge transaction fails" do
        @subscription.renew
        @subscription.should be_past_due
      end
    
      it "does not change renewal date" do
        @subscription.renew
        @subscription.next_renewal_on.should == @today
      end
    end
  end
  
  # -------------------------
  describe "cancel" do
    before :each do      
      SubscriptionTransaction.stub!(:credit).and_return(SubscriptionTransaction.new(:success => true))
      @plan = SubscriptionPlan.create( :name => 'basic', :rate_cents => 1000, :interval => 1)      
      @subscription = create_subscription( :plan => @plan )
      @today = Time.zone.today
      @subscription.next_renewal_on = @today + 6.days
      @subscription.state = 'active'
      # avoid stale instance during batch tests
      SubscriptionPlan.instance_variable_set('@default_plan', nil)
    end
    
    it "and_return true when successful" do
      @subscription.cancel.should be_true
    end
    
    it "reverts to default plan" do   
      @subscription.cancel
      @subscription.plan.should == SubscriptionPlan.default_plan    
    end
    
    # it "credit unused value back to credit card" do
    #   SubscriptionTransaction.should_receive(:credit).with(200, anything, :subscription => @subscription).and_return( SubscriptionTransaction.new(:success => true) )
    #   @subscription.cancel      
    # end
    
    it "sets state to free" do
      @subscription.cancel
      @subscription.should be_free
    end    
  end
  
  # -------------------------
  describe "days_remaining" do
    before :each do
      @subscription = create_subscription
    end
    
    it "and_return nil when next renewal is nil" do
      @subscription.next_renewal_on = nil
      @subscription.days_remaining.should be_nil
    end
    
    it "and_return 0 when next renewal is today" do
      @subscription.next_renewal_on = Time.zone.today
      @subscription.days_remaining.should == 0
    end

    it "and_return 3 when next renewal is 3 days from now" do
      @subscription.next_renewal_on = Time.zone.today + 3.days
      @subscription.days_remaining.should == 3
    end

    it "and_return -2 when next renewal is 2 days ago" do
      @subscription.next_renewal_on = Time.zone.today - 2.days
      @subscription.days_remaining.should == -2
    end
  end

  # -------------------------
  describe "trial_ends_on" do
    before :each do
      @subscription = create_subscription
    end
    
    it "is nil if no trial period in config" do
      SubscriptionConfig.stub!(:trial_period).and_return(0)
      @subscription.trial_ends_on.should be_nil
    end
    it "is current next renewal if presently in trial" do
      @subscription.state = "trial"
      @subscription.next_renewal_on = Time.zone.today + 3.days
      @subscription.trial_ends_on.should == Time.zone.today + 3.days
    end
    it "is from today if no plan defined yet (eg inquiring what it would be for a gui)" do
      @subscription.plan = nil
      @subscription.trial_ends_on.should == Time.zone.today + 30.days
    end
    it "is calculated from subscription creation date" do
      @plan = SubscriptionPlan.create( :name => 'basic', :rate_cents => 1000)
      @subscription.plan = @plan
      @subscription.created_at = Time.zone.now - 10.days
      @subscription.trial_ends_on.should == Time.zone.today + 20.days
    end
  end

  # -------------------------
  describe "due?" do
    before :each do
      @subscription = create_subscription( :plan => @plan )
    end
    
    it "and_return nil when next renewal is nil" do
      @subscription.next_renewal_on = nil
      @subscription.due?.should be_nil
    end
    
    it "and_return true next renewal is today" do
      @subscription.next_renewal_on = Time.zone.today
      @subscription.due?.should be_true
    end

    it "and_return false when next renewal is 3 days from now" do
      @subscription.next_renewal_on = Time.zone.today + 3.days
      @subscription.due?.should be_false
    end
    
    it "and_return true when due(3.days) and next renewal is 3 days from now" do
      @subscription.next_renewal_on = Time.zone.today + 3.days
      @subscription.due?(3.days).should be_true
    end

    it "and_return true when next renewal is 2 days ago" do
      @subscription.next_renewal_on = Time.zone.today - 2.days
      @subscription.due?.should be_true
    end
  end
  
  # -------------------------
  describe "check plan" do    
    it "checks if exceeds current plan" do
      @plan = SubscriptionPlan.create( :name => 'basic', :rate_cents => 1000 )      
      @subscriber = create_subscriber( :subscription_plan => @plan )
      @subscription = @subscriber.subscription
      @subscription.subscriber.should_receive(:subscription_plan_check).with(@plan).and_return("exceeded limits")
  
      @subscription.plan_check.should == "exceeded limits"
    end
    
    it "checks if exceeds another plan" do
      @plan = SubscriptionPlan.create( :name => 'basic', :rate_cents => 1000 )      
      @plan2 = SubscriptionPlan.create( :name => 'limited', :rate_cents => 1000 )      
      @subscriber = create_subscriber( :subscription_plan => @plan )
      @subscription = @subscriber.subscription
      @subscription.subscriber.should_receive(:subscription_plan_check).with(@plan2).and_return("exceeded limits")
  
      @subscription.plan_check(@plan2).should == "exceeded limits"
    end
    
    it "finds allowed plans" do
      @free         = SubscriptionPlan.create( :name => 'free', :rate_cents => 0, :interval => 1)      
      @plan         = SubscriptionPlan.create( :name => 'basic', :rate_cents => 1000 )      
      @plan2        = SubscriptionPlan.create( :name => 'limited', :rate_cents => 1000 )      
      @subscriber   = create_subscriber( :subscription_plan => @plan )
      @subscription = @subscriber.subscription
      @subscription.subscriber.should_receive(:subscription_plan_check).with(@free).and_return(nil)
      @subscription.subscriber.should_receive(:subscription_plan_check).with(@plan).and_return("exceeded limits")
      @subscription.subscriber.should_receive(:subscription_plan_check).with(@plan2).and_return(nil)
  
      @subscription.allowed_plans.should == [@free, @plan2]
    end
  end
  
  # -------------------------
  describe "change plan" do
    before :each do
      @plan     = SubscriptionPlan.create( :name => 'basic', :rate_cents => 1000, :interval => 1)      
      @new_plan = SubscriptionPlan.create( :name => 'pro', :rate_cents => 2000, :interval => 1)      
      @today = Time.zone.today
    end
    
    describe "when active" do
      before :each do
        @subscription = create_subscription( :plan => @plan )
        @subscription.created_at = @today - 1.year #dont calc we're in trial
        @subscription.next_renewal_on = @today + 6.days # remaining value = 1000/(30/6) = 200
        @subscription.state = 'active'
      end
      it "sets new plan" do
        @subscription.change_plan( @new_plan )
        @subscription.plan.should == @new_plan
      end
      it "deducts unused value" do
        @subscription.change_plan( @new_plan )
        @subscription.balance_cents.should == -200
      end
      it "still is active" do
        @subscription.change_plan( @new_plan )
        @subscription.should be_active
      end
      it "sets renewal date to today" do
        @subscription.change_plan( @new_plan )
        @subscription.next_renewal_on.should == @today
      end
    end
    
    describe "when in trial" do
      before :each do
        @subscription = create_subscription( :plan => @plan )
        @subscription.next_renewal_on = @today + 6.days
        @subscription.state = 'trial'
      end
      it "sets new plan" do
        @subscription.change_plan( @new_plan )
        @subscription.plan.should == @new_plan
      end
      it "still in trial" do
        @subscription.change_plan( @new_plan )
        @subscription.should be_trial
      end
      it "keeps trial end date" do
        days = @subscription.days_remaining
        @subscription.change_plan( @new_plan )
        @subscription.days_remaining.should == days
      end
    end

    describe "when past due" do
      before :each do
        @subscription = create_subscription( :plan => @plan )
        @subscription.created_at = @today - 1.year 
        @subscription.next_renewal_on = @today - 6.days
        @subscription.state = 'past_due'
        @subscription.balance = @plan.rate # 1000, remaining value = 800

        @subscription.change_plan( @new_plan )
      end
      it "sets new plan" do
        @subscription.plan.should == @new_plan
      end
      it "deducts unused (although unpaid) value" do
        @subscription.balance_cents.should == 200
      end
      it "is active (let renew handle it)" do
        @subscription.should be_active
      end
      it "sets renewal day to today" do
        @subscription.next_renewal_on.should == @today
      end
      it "resets warning level" do
        @subscription.warning_level.should be_nil
      end
    end
    
    # TODO
    #describe "when expired"
  end

  # -------------------------
  describe "charge_balance" do
    before :each do
      @user = create_subscriber
      @subscription = @user.subscription
      @subscription.profile.state = 'authorized'
      @subscription.profile.profile_key = '1'
      @subscription.update_attribute :balance_cents, 1500
      SubscriptionTransaction.stub!(:charge).and_return( SubscriptionTransaction.new(:success => true, :amount => Money.new(1500) ))
    end
    
    it "returns nil if zero balance" do
      @subscription.update_attribute :balance_cents, 0
      @subscription.charge_balance.should be_nil
    end
    it "returns false if no cc info" do
      @subscription.profile.state = 'no_info'
      @subscription.charge_balance.should be_false
    end
    it "returns amount charged if successful" do
      @subscription.charge_balance.should == Money.new(1500)
    end
    
    it "charges against balance" do
      @subscription.charge_balance
      @subscription.balance_cents.should == 0
    end
    
    it "charges credit card" do
      SubscriptionTransaction.should_receive(:charge).with(Money.new(1500), anything).and_return( SubscriptionTransaction.new(:success => true ))
      @subscription.charge_balance
    end
    
    it "saves the transaction" do
      SubscriptionTransaction.should_receive(:charge).and_return( SubscriptionTransaction.new(:success => true ))
      @subscription.charge_balance
      @subscription.transactions.count.should == 1
    end
    
    it "sets profile state to :authorized" do
      @subscription.profile.state = 'error'
      @subscription.charge_balance
      @subscription.profile.should be_authorized
    end
    
    describe "transaction fails" do
      before :each do
        SubscriptionTransaction.should_receive(:charge).and_return( SubscriptionTransaction.new(:success => false ))
      end
      it "returns false on error" do
        @subscription.charge_balance.should be_false
      end
      it "sets profile state to :error" do
        @subscription.charge_balance
        @subscription.profile.should be_error
      end
      it "does not change balance" do
        @subscription.charge_balance
        @subscription.balance_cents.should == 1500
      end
    end
  end
  
  # -------------------------
  describe "credit_balance" do
    before :each do
      @user = create_subscriber
      @subscription = @user.subscription
      @subscription.profile.state = 'authorized'
      @subscription.profile.profile_key = '1'
      @subscription.update_attribute :balance_cents, -1500
      SubscriptionTransaction.stub!(:credit).and_return( SubscriptionTransaction.new(:success => true, :amount => Money.new(1500) ))
    end
    
    it "returns nil if zero balance" do
      @subscription.update_attribute :balance_cents, 0
      @subscription.credit_balance.should be_nil
    end
    it "return false if no cc on file" do
      @subscription.profile.state = 'no_info'
      @subscription.credit_balance.should be_false
    end
    it "returns amount credited if successful" do
      @subscription.credit_balance.should == Money.new(1500)
    end
    it "credits balance" do
      @subscription.credit_balance
      @subscription.balance_cents.should == 0
    end    
    it "credits credit card" do
      SubscriptionTransaction.should_receive(:credit).with(1500, anything, :subscription => @subscription).and_return( SubscriptionTransaction.new(:success => true ))
      @subscription.credit_balance
    end   
    it "saves the transaction" do
      SubscriptionTransaction.should_receive(:credit).and_return( SubscriptionTransaction.new(:success => true ))
      @subscription.credit_balance
      @subscription.transactions.count.should == 1
    end    
    it "sets profile state to :authorized" do
      @subscription.profile.state = 'error'
      @subscription.credit_balance
      @subscription.profile.should be_authorized
    end
    
    describe "transaction fails" do
      before :each do
        SubscriptionTransaction.should_receive(:credit).and_return( SubscriptionTransaction.new(:success => false ))
      end
      it "returns false on error" do
        @subscription.credit_balance.should be_false
      end
      it "sets profile state to :error" do
        @subscription.credit_balance
        @subscription.profile.should be_error
      end
      it "does not change balance" do
        @subscription.credit_balance
        @subscription.balance_cents.should == -1500
      end
    end
  end
  
end   
