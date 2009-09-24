class SubscriptionPlan < ActiveRecord::Base
  has_many :subscriptions
  
  composed_of :rate, :class_name => 'Money', :mapping => [ %w(rate_cents cents) ]

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_presence_of :rate_cents  
  validates_numericality_of :interval # in months
  
  def free?
    rate.zero?
  end
  
  def prorated_value( days )
    # this calculation is a little off, we're going to assume 30 days/month rather than varying it month to month
    total_days = interval * 30
    daily_rate = rate_cents.to_f / total_days
    # round down to penny
    Money.new( (days * daily_rate).to_i )
  end
  
  # ---------------
  
  def self.default_plan
    default_plan = SubscriptionPlan.find_by_name(SubscriptionConfig.default_plan) if SubscriptionConfig.respond_to? :default_plan
    default_plan ||= SubscriptionPlan.first( :conditions => { :rate_cents => 0 })
    default_plan ||= SubscriptionPlan.create( :name => 'free' ) #bootstrapper and tests
  end
end