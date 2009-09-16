require File.dirname(__FILE__) + '/../spec_helper'

describe SubscriptionPlan do
  before :each do
    create_subscription_plans
  end
  
  it "gets free plan as default" do
    SubscriptionPlan.default_plan.should == @free
  end
  
  it "gets default plan from configuration" do
    SubscriptionPlan.instance_variable_set('@default_plan', nil)
    SubscriptionConfig.default_plan = 'basic'
    SubscriptionPlan.default_plan.should == @basic
    # tear down
    SubscriptionConfig.default_plan = 'free'
    SubscriptionPlan.instance_variable_set('@default_plan', nil)
  end
  
  it "says if plan is free" do
    @free.should      be_free
    @basic.should_not be_free
    @pro.should_not   be_free
  end
  
  it "calculates prorated value" do
    @basic.prorated_value(30).should == @basic.rate
    @basic.prorated_value(0).should == Money.new(0)
    @basic.prorated_value(10).should == @basic.rate / 3
  end
  
end
