# acts_as_subscriber
module Saasramp           #:nodoc:
  module Acts                 #:nodoc:
    module Subscriber         #:nodoc:
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      module ClassMethods
        def acts_as_subscriber(options = {})
          has_one :subscription, :dependent => :destroy, :as => :subscriber
          validates_associated :subscription
          
          include Saasramp::Acts::Subscriber::InstanceMethods
          extend Saasramp::Acts::Subscriber::SingletonMethods
        end
      end
      
      module SingletonMethods
      end
      
      module InstanceMethods
        # delegate for easier user forms
        # for example, to sign up params[:user] => { :username => 'foo', :subscription_plan => '2', etc. }
        attr_accessor :subscription_plan
        
  		  def subscription_plan=(plan)
  		    # ensure subscription exists when plan set from new or create
  		    self.build_subscription if subscription.nil?
 		      # arg can be object or id
 		      subscription.plan = plan.is_a?(SubscriptionPlan) ? plan : SubscriptionPlan.find_by_id(plan)
  			end
  			
  			def subscription_plan
  			  subscription.plan 
  		  end
  		  
  		  # overwrite this method
  		  # compare subscriber to the plan's limits
  		  # return a blank value if ok (nil, false, [], {}), anything else means subscriber has exceeded limits
  		  # maybe should make this a callback option to acts_as_subscriber
  		  def subscription_plan_check(plan)
  		    "foobar"
  		    # example:
          # exceeded = {}
          # exceeded[:memory_used] = plan.max_memory if subscriber.memory_used > plan.max_memory
          # exceeded[:file_count]  = plan.max_files  if subscriber.file_count > plan.max_files
          # exceeded
		    end
  		  
        protected
        
        # ensure there's always a subscription defined
        def after_initialize
          self.build_subscription if subscription.nil?
        end
      end
      
    end
  end
end

ActiveRecord::Base::send(:include, Saasramp::Acts::Subscriber)
