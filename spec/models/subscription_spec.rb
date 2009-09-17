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
      @subscription = Subscription.create( :subscriber_id => 1, :subscriber_type => 'FakeUser', :plan => @plan )
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
      @subscription = Subscription.create( :subscriber_id => 1, :subscriber_type => 'FakeUser', :plan => @plan )
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
      #@subscription.next_renewal_on.should == (Time.now.midnight + 1.month).to_date
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
    
    it "credit unused value back to credit card" do
      SubscriptionTransaction.should_receive(:credit).with(200, anything, :subscription => @subscription).and_return( SubscriptionTransaction.new(:success => true) )
      @subscription.cancel      
    end
    
    it "sets state to free" do
      @subscription.cancel
      @subscription.should be_free
    end    
  end
  
  # -------------------------
  describe "days_remaining" do
    before :each do
      @subscription = create_subscription( :plan => @plan )
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
  
      @subscription.exceeds_plan.should == "exceeded limits"
    end
    
    it "checks if exceeds another plan" do
      @plan = SubscriptionPlan.create( :name => 'basic', :rate_cents => 1000 )      
      @plan2 = SubscriptionPlan.create( :name => 'limited', :rate_cents => 1000 )      
      @subscriber = create_subscriber( :subscription_plan => @plan )
      @subscription = @subscriber.subscription
      @subscription.subscriber.should_receive(:subscription_plan_check).with(@plan2).and_return("exceeded limits")
  
      @subscription.exceeds_plan(@plan2).should == "exceeded limits"
    end
    
    it "finds allowed plans" do
      @plan = SubscriptionPlan.create( :name => 'basic', :rate_cents => 1000 )      
      @plan2 = SubscriptionPlan.create( :name => 'limited', :rate_cents => 1000 )      
      @subscriber = create_subscriber( :subscription_plan => @plan )
      @subscription = @subscriber.subscription
      @subscription.subscriber.should_receive(:subscription_plan_check).with(@plan).and_return("exceeded limits")
      @subscription.subscriber.should_receive(:subscription_plan_check).with(@plan2).and_return(nil)
  
      @subscription.allowed_plans.should == [@plan2]
    end
  end
  
  # -------------------------
  describe "change plan" do
    before :each do
      @plan     = SubscriptionPlan.create( :name => 'basic', :rate_cents => 1000, :interval => 1)      
      @new_plan = SubscriptionPlan.create( :name => 'pro', :rate_cents => 2000, :interval => 1)      
      @today = Time.zone.today
      SubscriptionTransaction.stub!(:charge).and_return(SubscriptionTransaction.new(:success => true))
    end
    
    describe "when active" do
      before :each do
        @subscription = create_subscription( :plan => @plan )
        @subscription.next_renewal_on = @today + 6.days # remaining value = 1000/(30/6) = 200
        @subscription.state = 'active'
      end
      it "sets new plan" do
        @subscription.change_plan( @new_plan )
        @subscription.plan.should == @new_plan
      end
      it "charges only incremental higher cost" do
        SubscriptionTransaction.should_receive(:charge).with(Money.new(1800),anything).and_return( SubscriptionTransaction.new(:success => true) )        
        @subscription.change_plan( @new_plan )
        @subscription.reload
        @subscription.balance_cents.should == 0
      end
      it "deducts unused value" do
        @new_plan.rate_cents = 700
        SubscriptionTransaction.should_receive(:charge).with(Money.new(500),anything).and_return( SubscriptionTransaction.new(:success => true) )       
        @subscription.change_plan( @new_plan )
        @subscription.reload
        @subscription.balance_cents.should == 0
      end
      it "leaves a balance when new plan is less than unused value" do
        @new_plan.rate_cents = 75
        SubscriptionTransaction.should_receive(:charge).never     
        @subscription.change_plan( @new_plan )
        @subscription.reload
        @subscription.balance_cents.should == -125
      end
      it "still is active" do
        @subscription.change_plan( @new_plan )
        @subscription.should be_active
      end
      it "sets renewal date from today" do
        @subscription.change_plan( @new_plan )
        @subscription.next_renewal_on.should == @today + 1.month
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
        @subscription.next_renewal_on = @today - 6.days
        @subscription.state = 'past_due'
        @subscription.balance = @plan.rate # 1000, remaining value = 800
      end
      
      describe "and credit card now goes through" do
        it "sets new plan" do
          @subscription.change_plan( @new_plan )
          @subscription.plan.should == @new_plan
        end
        it "deducts unused (although unpaid) value" do
          SubscriptionTransaction.should_receive(:charge).with(Money.new(2200),anything).and_return( SubscriptionTransaction.new(:success => true) )       
          @subscription.change_plan( @new_plan )
          @subscription.balance_cents.should == 0
        end
        it "is now active" do
          @subscription.change_plan( @new_plan )
          @subscription.should be_active
        end
        it "sets next renewal from today" do
          @subscription.change_plan( @new_plan )
          @subscription.next_renewal_on.should == @today + 1.month
        end
      end
    
      describe "and credit card still fails" do
        before :each do
          SubscriptionTransaction.stub!(:charge).and_return(SubscriptionTransaction.new(:success => false))
          @subscription.warning_level = 2
          @subscription.change_plan( @new_plan )
        end       
        it "sets new plan" do
          @subscription.plan.should == @new_plan
        end
        it "deducts unused (although unpaid) value" do
          @subscription.balance_cents.should == 2200
        end
        it "is still past due" do
          @subscription.should be_past_due
        end
        it "sets renewal day to today" do
          @subscription.next_renewal_on.should == @today
        end
        it "resets warning level" do
          @subscription.warning_level.should be_nil
        end
      end
    end
    
    #describe "when expired"
  end

  # -------------------------
  describe "charge_balance" do
    before :each do
      @user = create_subscriber
      @subscription = @user.subscription
      @subscription.update_attribute :balance_cents, 1500
      SubscriptionTransaction.stub!(:charge).and_return( SubscriptionTransaction.new(:success => true ))
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
        @subscription.profile.state = 'authorized'
        @subscription.charge_balance
      end
      it "sets profile state to :error" do
        @subscription.profile.should be_error
      end
      it "does not change balance" do
        @subscription.balance_cents.should == 1500
      end
    end
  end
  
  # -------------------------
  describe "credit_balance" do
    before :each do
      @user = create_subscriber
      @subscription = @user.subscription
      @subscription.update_attribute :balance_cents, -1500
      SubscriptionTransaction.stub!(:credit).and_return( SubscriptionTransaction.new(:success => true ))
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
        @subscription.profile.state = 'authorized'
        @subscription.credit_balance
      end
      it "sets profile state to :error" do
        @subscription.profile.should be_error
      end
      it "does not change balance" do
        @subscription.balance_cents.should == -1500
      end
    end
  end
  
end   
