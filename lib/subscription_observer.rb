# use this observer to send out email notifications when transactions are saved
# unclutters the models and ensures users get notified whenever their credit card is accessed
# tracks warning levels so the same message isnt duplicated, 
# and handles when subscription is expired (move that out of here? but we did try to charge the card one last time)
# Install in environment.rb config.active_record.observers = :subscription_observer

class SubscriptionObserver < ActiveRecord::Observer
  observe :subscription_transaction
  
  def after_save(transaction)
    sub = transaction.subscription
    case transaction.action
    when 'charge'
      if transaction.success?
        SubscriptionConfig.mailer.deliver_charge_success(sub, transaction)
      else 
        sub.increment!(:warning_level)
        case sub.warning_level
        when 1
          SubscriptionConfig.mailer.deliver_charge_failure(sub, transaction)
        when 2
          SubscriptionConfig.mailer.deliver_second_charge_failure(sub, transaction)
        else
          # expired: do in the app whatever it means to become expired
          # send no mail here
        end
      end
      
    when 'credit', 'refund'
      if transaction.success?
        SubscriptionConfig.mailer.deliver_credit_success(sub, transaction)
      end
      # else no email
      
    else # 'validate', 'store', 'update', 'unstore'
      # send no email
    end
  end
  
end
