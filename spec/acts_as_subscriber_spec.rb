# use this file in models that have acts_as_subscriber
# and add to app spec_helper.rb
#   require 'vendor/plugins/saasramp/spec/acts_as_subscriber_spec'

describe "acts as subscriber", :shared => true do
  it "has one subscription" do
    should have_one :subscription
  end
  
  it "has default plan when no subscription" do
    @user = subject # ?!
    @user.subscription_plan.should == SubscriptionPlan.default_plan
    x=1
    #@description_args.first
    # @subscriber = 
  end
    
  it "builds subscription when set the plan"
end
