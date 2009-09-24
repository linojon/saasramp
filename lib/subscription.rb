class Subscription < ActiveRecord::Base
  
  belongs_to :subscriber, :polymorphic => true  
  belongs_to :plan,         :class_name => 'SubscriptionPlan'
  has_one    :profile,      :class_name => 'SubscriptionProfile', :dependent => :destroy  
  has_many   :transactions, :class_name => 'SubscriptionTransaction', :dependent => :destroy, :order => 'id DESC' #created_at is in seconds not microseconds?! so assume higher id's are newer
  composed_of :balance, :class_name => 'Money', :mapping => [ %w(balance_cents cents) ], :allow_nil => true
  
  before_validation :initialize_defaults
  after_create      :initialize_state_from_plan
  # if you destroy a subscription all transaction history is lost so you may not really want to do that
  before_destroy    :cancel
  
  attr_accessible # none
  
  # ------------
  # states: :pending, :free, :trial, :active, :past_due, :expired
  state_machine :state, :initial => :pending do 
    # set next renewal date when entering a state
    before_transition any => :free,     :do => :setup_free
    before_transition any => :trial,    :do => :setup_trial
    before_transition any => :active,   :do => :setup_active
    
    # always reset warning level when entering a different state
    before_transition any => [any - same] do |sub| sub.warning_level = nil end
    
    # for simpicity, event names are the same as the state
    event :free do
      transition any => :free
    end
    event :trial do
      transition [:pending, :free] => :trial
    end
    event :active do
      transition any => :active
    end
    event :past_due do
      transition (any - [:expired]) => :past_due, :if => Proc.new {|s| s.due? }
    end
    event :expired do
      transition any => :expired
    end
    
  end
    
  def setup_free
    self.next_renewal_on = nil 
  end
  
  def setup_trial
    start = Time.zone.today
    self.next_renewal_on = start + SubscriptionConfig.trial_period.days
  end
  
  def setup_active
    # next renewal is from when subscription ran out (to change this behavior, set next_renewal to nil before doing renew)
    start = next_renewal_on || Time.zone.today
    self.next_renewal_on = start + plan.interval.months
  end
  
  # returns nil if not past due, false for failed, true for success, or amount charged for success when card was charged
  def renew
    # make sure it's time
    return nil unless due?
    transaction do # makes this atomic
      #debugger
      # adjust current balance (except for re-tries)
      self.balance += plan.rate unless past_due?
      
      # charge the amount due
      case charge = charge_balance
        
      # transaction failed: past due and return false
      when false:   past_due && false
        
      # not charged, subtracted from current balance: update renewal and return true
      when nil:     active && true
        
      # card was charged: update renewal and return amount
      else          active && charge
      end
    end
  end
  
  # cancelling can mean revert to a free plan and credit back their card
  # if it also means destroying or disabling the user account, that happens elsewhere in your app 
  # returns same results as change_plan (nil, false, true)
  def cancel
    change_plan SubscriptionPlan.default_plan
    # uncomment if you want to refund unused value to their credit card, otherwise it just says on balance here
    #credit_balance
  end
   
  # ------------
  # changing the subscription plan
  # usage: e.g in a SubscriptionsController
  # if !@subscription.exceeds_plan?( plan )  &&  @subscription.change_plan( plan )
  #   @subscription.renew
  # end
  
  # the #change_plan method sets the new current plan, 
  # prorates unused service from previous billing
  # billing cycle for the new plan starts today
  # if was in trial, stays in trial until the trial period runs out
  # note, you should call #renew right after this
  
  # returns nil if no change, false if failed, or true on success
  
  def change_plan( new_plan )
    # not change?
    return if plan == new_plan
    
    # return unused prepaid value on current plan
    self.balance -= plan.prorated_value( days_remaining ) if active?
    # or they owe the used (although unpaid) value on current plan [comment out if you want to be more forgiving]
    self.balance -= plan.rate - plan.prorated_value( past_due_days ) if past_due?
    
    # prorate days since creation if was free (is this what we want?)
    trial_ends = created_at.to_date + SubscriptionConfig.trial_period.days if plan.nil? || plan.free?
    # prorate unused trial days if in trial
    trial_ends = next_renewal_on if trial?
     
    # update the plan
    self.plan = new_plan
    
    # update the state and initialize the renewal date
    if plan.free?
      self.free
      
    elsif trial_ends #aka in trial
      self.trial
      self.next_renewal_on = trial_ends
    
    else #active or past due
      # note, past due grace period resets like active ones due today, ok?
      self.active
      self.next_renewal_on = Time.zone.today
      self.warning_level = nil
    end
    # past_due and expired fall through till next renew
    
    # save changes so far
    save
  end
  
  # list of plans this subscriber is allowed to choose
  # use the subscription_plan_check callback in subscriber model
  def allowed_plans
    SubscriptionPlan.all.collect {|plan| plan unless exceeds_plan?(plan) }.compact
  end
  
  # test if subscriber can use a plan, returns true or false
  def exceeds_plan?( plan = self.plan)
    !exceeds_plan(plan).blank?
  end
  
  # check if subscriber can use a plan and returns list of attributes exceeded, or blank for ok
  def exceeds_plan( plan = self.plan)
    subscriber.subscription_plan_check(plan)       
  end  
  
  # -------------
  # charge the current balance against the subscribers credit card  
  # return amount charged on success, false for failure, nil for nothing happened
  def charge_balance
    #debugger
    # nothing to charge? (0 or a credit)
    return if balance_cents <= 0
    # no cc on fle
    return false if profile.no_info? || profile.profile_key.nil?

    transaction do # makes this atomic
      #debugger
      # charge the card
      tx  = SubscriptionTransaction.charge( balance, profile.profile_key )
      # save the transaction
      transactions.push( tx )
      # set profile state and reset balance
      if tx.success
        self.update_attribute :balance_cents, 0
        profile.authorized
      else
        profile.error
      end
      tx.success && tx.amount
    end
  end

  # credit a negative balance to the subscribers credit card
  # returns amount credited on success, false for failure, nil for nothing 
  def credit_balance
    #debugger
    # nothing to credit?
    return if balance_cents >= 0
    # no cc on fle
    return false if profile.no_info? || profile.profile_key.nil?

    transaction do # makes this atomic
      #debugger
      # credit the card
      tx  = SubscriptionTransaction.credit( -balance_cents, profile.profile_key, :subscription => self )
      # save the transaction
      transactions.push( tx )
      # set profile state and reset balance
      if tx.success
        self.update_attribute :balance_cents, 0
        profile.authorized
      else
        profile.error
      end
      tx.success && tx.amount
    end
  end
   
  # -------------
  # true if account is due today or before
  def due?( days_from_now = 0)
    days_remaining && (days_remaining <= days_from_now)
  end
  
  # number of days until next renewal
  def days_remaining
    (next_renewal_on - Time.zone.today) unless next_renewal_on.nil?
  end
  
  # number of days account is past due (negative of days_remaining)
  def past_due_days
    (Time.zone.today - next_renewal_on) unless next_renewal_on.nil?
  end
  
  # number of days until account expires
  def grace_days_remaining
    (next_renewal_on + SubscriptionConfig.grace_period.days - Time.zone.today) if past_due?
  end
  
  # most recent transaction
  def latest_transaction
    transactions.first
  end
  
  # ------------
  # named scopes
  # used in daily rake task
  # note, 'due' scopes find up to and including the specified day
  named_scope :due_now, lambda { 
    { :conditions => ["next_renewal_on <= ?", Time.zone.today] }
  }
  named_scope :due_on, lambda {|date|
    { :conditions => ["next_renewal_on <= ?", date] }
  }
  named_scope :due_in, lambda {|days|
    { :conditions => ["next_renewal_on <= ?", Time.zone.today + days] }
  }
  named_scope :due_ago, lambda {|days|
    { :conditions => ["next_renewal_on <= ?", Time.zone.today - days] }
  }
  
  named_scope :with_no_warnings, lambda {
    { :conditions => { :warning_level => nil } }
  }
  named_scope :with_warning_level, lambda {|level|
    { :conditions => { :warning_level => level } }
  }
  
  # -----------
  protected
  
  def initialize_defaults
    # default plan
    self.plan ||= SubscriptionPlan.default_plan
    # bug fix: when aasm sometimes doesnt initialize
    self.state ||= 'pending'
  end
  
  def initialize_state_from_plan
    # build profile if not present
    self.create_profile if profile.nil?
    # initialize the state (and renewal date) [doing this after create since aasm saves]
    if plan.free?
      self.free
    elsif SubscriptionConfig.trial_period > 0
      self.trial
    else
      self.active
    end
  end
  
end
