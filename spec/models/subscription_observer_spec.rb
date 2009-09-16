require File.dirname(__FILE__) + '/../spec_helper'
unless ActiveRecord::Base.observers.include? :subscription_observer
  puts "Cannot run specs on SubscriptionObserver. Please add the following to environment.rb"
  puts "  config.active_record.observers = :subscription_observer"
else
describe SubscriptionObserver do
  before :all do
    ActiveRecord::Observer.allow_peeping_toms = true if ActiveRecord::Observer.respond_to?(:allow_peeping_toms)
  end
  before :each do
    @subscriber = create_subscriber( :subscription_plan => @plan )
    @subscription = @subscriber.subscription
    mailer_setup
  end
  after :all do
    ActiveRecord::Observer.allow_peeping_toms = false if ActiveRecord::Observer.respond_to?(:allow_peeping_toms)
  end
  
  describe "charge transaction" do
    before :each do
      @params = {
        :success => true, 
        :action => 'charge', 
        :amount_cents => 995
      }
    end
    
    it "deliver_charge_success when success" do
      @subscription.transactions.create @params
      number_of_emails_sent.should == 1
      last_email_sent.subject.should =~ /Service invoice/
    end
    
    it "deliver_charge_failure when past due first warning" do
      @subscription.transactions.create @params.merge( :success => false )
      number_of_emails_sent.should == 1
      last_email_sent.subject.should =~ /Billing error/
    end
    
    it "deliver_second_charge_failure when past due 2nd warning" do
      @subscription.update_attribute :warning_level, 1
      @subscription.transactions.create @params.merge( :success => false )
      number_of_emails_sent.should == 1
      last_email_sent.subject.should =~ /Second notice: Your subscription is set to expire/      
    end
    
    # it "deliver_subscription_expired when past due > 2 warnings" do
    #   @subscription.update_attribute :warning_level, 2
    #   @subscription.transactions.create @params.merge( :success => false )
    #   number_of_emails_sent.should == 1
    #   last_email_sent.subject.should =~ /Your subscription has expired/      
    # end    
  end

  describe "credit and refund transactions" do
    before :each do
      @params = {
        :success => true, 
        :action => 'credit', 
        :amount_cents => 995
      }
    end
    it "deliver_credit_success on credit when success" do
      @subscription.transactions.create @params
      number_of_emails_sent.should == 1
      last_email_sent.subject.should =~ /Credit/
    end
  end
end
end