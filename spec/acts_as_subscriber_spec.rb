# use this file in models that have acts_as_subscriber
# and add to RAILS_ROOT/spec/spec_helper.rb
#   require File.dirname(__FILE__) + '/../vendor/plugins/saasramp/spec/acts_as_subscriber_spec'

describe "acts as subscriber", :shared => true do
  before :each do
    @user = subject # (?!)
  end
  
  it "has one subscription" do
    @user.should respond_to(:subscription)
  end
  
  it "has default plan when no subscription" do
    @user.save
    @user.subscription_plan.should == SubscriptionPlan.default_plan
  end
  
  it "sets subscription plan" do
    plan = SubscriptionPlan.new( :name => 'basic' )
    @user.subscription_plan = plan
    @user.subscription.plan.should == plan
  end
  
  it "gets subscription plan" do
    plan = SubscriptionPlan.new( :name => 'basic' )
    @user.subscription.plan = plan
    @user.subscription_plan.should == plan    
  end
end
