# use this file in models that have acts_as_subscriber
# and add to RAILS_ROOT/spec/spec_helper.rb
#   require File.dirname(__FILE__) + '/../vendor/plugins/saasramp/spec/acts_as_subscriber_spec'

describe "acts as subscriber", :shared => true do
  before :each do
    @subscriber = subject # (?!)
  end
  
  it "has one subscription" do
    @subscriber.should respond_to(:subscription)
  end
  
  it "has default plan when no subscription" do
    @subscriber.save
    @subscriber.subscription_plan.should == SubscriptionPlan.default_plan
  end
  
  it "sets subscription plan" do
    plan = SubscriptionPlan.new( :name => 'basic' )
    @subscriber.subscription_plan = plan
    @subscriber.subscription.plan.should == plan
  end
  
  it "sets subscription plan by id" do
    plan = SubscriptionPlan.create( :name => 'basic' )
    @subscriber.subscription_plan = plan.id
    @subscriber.subscription.plan.should == plan
  end
  
  it "sets subscription plan by name" do
    plan = SubscriptionPlan.create( :name => 'basic' )
    @subscriber.subscription_plan = 'basic'
    @subscriber.subscription.plan.should == plan
  end
  
  it "gets subscription plan" do
    plan = SubscriptionPlan.new( :name => 'basic' )
    @subscriber.subscription.plan = plan
    @subscriber.subscription_plan.should == plan    
  end
end
