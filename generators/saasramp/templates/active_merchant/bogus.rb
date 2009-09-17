# monkeypatch the gateway
include ActiveMerchant::Billing

class ActiveMerchant::Billing::Response
#class BogusResponse < ActiveMerchant::Billing::Response
  def token
    @params[:billingid]
  end
end

class ActiveMerchant::Billing::BogusGateway
# module ActiveMerchant #:nodoc:
#   module Billing #:nodoc:
#     class Bogus < Gateway
  
  # handle billingid in addition to credit card
  def purchase(money, ident, options = {})
    number = ident.is_a?(ActiveMerchant::Billing::CreditCard) ? ident.number : ident
    case number
    when '1'
      ActiveMerchant::Billing::Response.new(true, SUCCESS_MESSAGE, 
        {:authorized_amount => money.to_s}, :test => true, :authorization => AUTHORIZATION )
    when '2'
      ActiveMerchant::Billing::Response.new(false, FAILURE_MESSAGE, 
        {:authorized_amount => money.to_s, :error => FAILURE_MESSAGE }, :test => true)
    else
      raise Error, ERROR_MESSAGE
    end      
  end
  
  # fix apparent blantant bug in bogus.rb
  def credit(money, ident, options = {})
    case ident
    when '1'
      Response.new(true, SUCCESS_MESSAGE, 
        {:paid_amount => money.to_s}, :test => true)
    when '2'
      Response.new(false, FAILURE_MESSAGE, 
        {:paid_amount => money.to_s, :error => FAILURE_MESSAGE }, :test => true)
    else
      raise Error, ERROR_MESSAGE
    end
  end  
  
# end
# end
end

