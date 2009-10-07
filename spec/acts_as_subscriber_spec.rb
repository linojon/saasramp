# use this file in models that have acts_as_subscriber
# usage: in the subscriber's spec file add
#
#  require File.dirname(__FILE__) + '/../vendor/plugins/saasramp/spec/acts_as_subscriber_spec'
#  describe User, "subscriber"
#    before :each do
#      @subscriber = User.create(:username => 'me', :password => 'secret', :password_confirmation => 'secret')
#    end
#    it_should_behave_like "a subscriber"
#  end

describe "a subscriber", :shared => true do
  before :each do
    @subscriber ||= subject
    @subscriber.save.should be_true # just incase you did #new not #create :)
  end
  
  it "has one subscription" do
    @subscriber.should respond_to(:subscription)
  end
  
  it "has default plan when no subscription" do
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
  
  if described_class.respond_to?(:paranoid?) && described_class.paranoid?
    describe "when paranoid" do
      it "does not actually destroy subscription" do
        @subscriber.destroy
        described_class.find_by_id( @subscriber.id ).should be_nil
        described_class.find_by_id( @subscriber.id, :with_deleted => true ).should_not be_nil
        Subscription.find_by_id( @subscriber.subscription.id ).should_not be_nil
      end
    
      it "destroys subscription on destroy! (bang)" do
        @subscriber.destroy!
        described_class.find_by_id( @subscriber.id ).should be_nil
        described_class.find_by_id( @subscriber.id, :with_deleted => true ).should be_nil
        Subscription.find_by_id( @subscriber.subscription.id ).should be_nil
      end
    end
  else
    it "destroys subscription" do
      @subscriber.destroy
      Subscription.find_by_id( @subscriber.subscription.id ).should be_nil
    end  
  end
end
