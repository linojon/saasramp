# SubscriptionTransaction encapsulates the ActiveMerchant gateway methods
# providing a consistent api for the rest of the SaasRamp plugin

class SubscriptionTransaction < ActiveRecord::Base
  belongs_to  :subscription
  serialize   :params
  composed_of :amount, :class_name => 'Money', :mapping => [ %w(amount_cents cents) ], :allow_nil => true
  attr_accessor :token
  
  # find recent 'charge' transactions that are greater or equal to amount
  named_scope :charges_at_least, lambda {|amount|
    { :conditions => ["action = ? AND amount_cents >= ?", 'charge', amount.cents],
      :order => "created_at DESC" }
  }
  
  class << self
    # note, according to peepcode pdf, many gateways require a unique order_id on each transaction
    
    # validate card via transaction
    def validate_card( credit_card, options ={})
      options[:order_id] ||= unique_order_number
      # authorize $1
      amount = 100
      result = process( 'validate', amount ) do |gw|
        gw.authorize( amount, credit_card, options )
      end
      if result.success?
        # void it
        result = process( 'validate' ) do |gw|
          gw.void( result.reference, options )
        end
      end
      result
    end
    
    def store( credit_card, options = {})
      options[:order_id] ||= unique_order_number
      process( 'store' ) do |gw|
        gw.store( credit_card, options )
      end
    end

    def update( profile_key, credit_card, options = {})
      options[:order_id] ||= unique_order_number
      # some gateways can update, otherwise unstore/store it
      # thus, always capture the profile key in case it changed
      if SubscriptionConfig.gateway.respond_to?(:update)
        process( 'update' ) do |gw|
          gw.update( profile_key, credit_card, options )
        end
      else
        process( 'update' ) do |gw|
          gw.unstore( profile_key, options )
          gw.store( credit_card, options )
        end
      end
    end

    def unstore( profile_key, options = {})
      options[:order_id] ||= unique_order_number
      process( 'unstore' ) do |gw|
        gw.unstore( profile_key, options )
      end
    end


    def charge( amount, profile_key, options ={})
      options[:order_id] ||= unique_order_number
      if SubscriptionConfig.gateway.respond_to?(:purchase)
        process( 'charge', amount ) do |gw|
          gw.purchase( amount, profile_key, options )
        end        
      else
        # do it in 2 transactions
        process( 'charge', amount ) do |gw|
          result = gw.authorize( amount, profile_key, options )
          if result.success?
            gw.capture( amount, result.reference, options )
          else
            result
          end
        end
      end
    end
    
    # credit will charge back to the credit card
    # some gateways support doing arbitrary credits, others require a transaction id, 
    # we encapsulate this difference here, looking for a recent successful charge if necessary
    # Note, refund expects the subscription object to be passed in options so it can find a recent charge

    # Note, when using refund (vs credit), the gateway needs time to process the purchase before we can refund against it
    # for example according to Authorize.net support, thats about every 10 minute in their test environment
    # in production they "only settle once a day after the merchant defined Transaction Cut Off Time."
    # so if the credit fails (and transaction was "refund") the app should tell the user to try again in a day (?!)
    
    def credit( amount, profile_key, options = {})
      #debugger
      options[:order_id] ||= unique_order_number
      if SubscriptionConfig.gateway.respond_to?(:credit)
        process( 'credit', amount) do |gw|
          gw.credit( amount, profile_key, options )
        end
      else
        # need to refund against a previous charge (by this subscriber!)
        subscription = options[:subscription]
        tx = subscription.transactions.charges_at_least( amount ).first
        if tx
          process( 'refund', amount ) do |gw|
            # note, syntax follows void 
            gw.refund( tx.reference, options.merge(:amount => amount) )
          end
        end
      end
    end

    private
    
    def process( action, amount = nil)
      #debugger
      result = SubscriptionTransaction.new
      result.amount_cents = amount.is_a?(Money) ? amount.cents : amount
      #result.amount       = amount
      result.action       = action
      begin 
        response = yield SubscriptionConfig.gateway 

        result.success   = response.success? 
        result.reference = response.authorization 
        result.token     = response.token
        result.message   = response.message 
        result.params    = response.params 
        result.test      = response.test? 
      rescue ActiveMerchant::ActiveMerchantError => e 
        result.success   = false 
        result.reference = nil 
        result.message   = e.message 
        result.params    = {} 
        result.test      = SubscriptionConfig.gateway.test? 
      end 
      # TODO: LOGGING
      result 
    end 
    
    # maybe should make this a callback option to acts_as_subscriber
    def unique_order_number
      # "#{Time.now.to_i}-#{rand(1_000_000)}"
      ActiveMerchant::Utils::generate_unique_id
    end
  end
end
