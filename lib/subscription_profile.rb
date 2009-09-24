class SubscriptionProfile < ActiveRecord::Base  
  belongs_to            :subscription 
  #validates_presence_of :subscription_id   
  
  attr_accessor       :request_ip, :credit_card
  validate            :validate_card  
  before_save         :store_card
  before_destroy      :unstore_card
  
  attr_accessible # none
  
  # ------------
  state_machine :state, :initial => :no_info do
    event :authorized do 
      transition any => :authorized
    end
    event :error do
      transition any => :error
    end
    event :remove do
      transition (any - [:no_info]) => :no_info
    end
  end
  
  # ------------
  # behave like it's 
  #   has_one :credit_card 
  #   accepts_nested_attributes_for :credit_card
   
  def credit_card=( card_or_params )
    @credit_card = case card_or_params
      when ActiveMerchant::Billing::CreditCard, nil
        card_or_params
      else
        ActiveMerchant::Billing::CreditCard.new(card_or_params)
      end
  end
  
  def new_credit_card
    # populate new card with some saved values
    ActiveMerchant::Billing::CreditCard.new(
      :first_name  => card_first_name,
      :last_name   => card_last_name,
      # :address etc too if we have it
      :type        => card_type
    )
  end
  
  # -------------
  # move this into a test helper...
  def self.example_credit_card_params( params = {})
    case SubscriptionConfig.gateway_name
      when 'braintree'
        { 
          :first_name         => 'First Name', 
          :last_name          => 'Last Name', 
          :type               => 'visa',
          :number             => '4111111111111111', 
          :month              => '10', 
          :year               => '2012', 
          :verification_value => '999' 
        }.merge( params )

      when 'bogus'
        { 
          :first_name         => 'First Name', 
          :last_name          => 'Last Name', 
          :type               => 'bogus',
          :number             => '1', 
          :month              => '10', 
          :year               => '2012', 
          :verification_value => '999' 
        }.merge( params )
        
      end
  end
  
  # -------------
  private
  
  # validate :validate_card
  def validate_card
    #debugger
    return if credit_card.nil?
    # first validate via ActiveMerchant local code
    unless credit_card.valid?
      # collect credit card error messages into the profile object
      #errors.add(:credit_card, "must be valid") 
      credit_card.errors.full_messages.each do |message|
        errors.add_to_base message
      end
      return
    end
    
    if SubscriptionConfig.validate_via_transaction
      transaction do # makes this atomic
        tx = SubscriptionTransaction.validate_card( credit_card )
        subscription.transactions.push( tx )
        if ! tx.success?
          #errors.add(:credit_card, "failed to #{tx.action} card: #{tx.message}")
          errors.add_to_base "Failed to #{tx.action} card: #{tx.message}"
          return
        end
      end
    end
    true
  end
  
  def store_card
    #debugger
    return unless credit_card && credit_card.valid?
    
    transaction do # makes this atomic
      if profile_key
        tx  = SubscriptionTransaction.update( profile_key, credit_card)
      else
        tx  = SubscriptionTransaction.store(credit_card)
      end
      subscription.transactions.push( tx )    
      if tx.success?
        # remember the token/key/billing id (whatever)
        self.profile_key = tx.token
    
        # remember some non-secure params for convenience
        self.card_first_name     = credit_card.first_name
        self.card_last_name      = credit_card.last_name
        self.card_type           = credit_card.type
        self.card_display_number = credit_card.display_number
        self.card_expires_on     = credit_card.expiry_date.expiration.to_date
    
        # clear the card in memory
        self.credit_card = nil
    
        # change profile state
        self.state = 'authorized' # can't call authorized! here, it saves
        
      else # ! tx.success
        #errors.add(:credit_card, "failed to #{tx.action} card: #{tx.message}")
        errors.add_to_base "Failed to #{tx.action} card: #{tx.message}"
      end
      
      tx.success
    end
  end
  
  def unstore_card
    return if no_info? || profile_key.nil?
    transaction do # atomic
      tx  = SubscriptionTransaction.unstore( profile_key )
      subscription.transactions.push( tx )
      if tx.success?
        # clear everything in case this is ever called without destroy 
        self.profile_key         = nil
        self.card_first_name     = nil
        self.card_last_name      = nil
        self.card_type           = nil
        self.card_display_number = nil
        self.card_expires_on     = nil
        self.credit_card         = nil
       # change profile state
        self.state               = 'no_info' # can't call no_info! here, it saves
      else
        #errors.add(:credit_card, "failed to #{tx.action} card: #{tx.message}")
        errors.add_to_base "Failed to #{tx.action} card: #{tx.message}"
      end
      tx.success
    end
  end
    
end
