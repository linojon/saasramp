# this file represents major hacking on the gateway, culled from various sources
# hopefully we'll integrate it into the Authorize.net gateway itself and eliminate this gorilla monkey patching
# references:
#   http://gist.github.com/147194
#  https://jadedpixel.lighthouseapp.com/projects/11599/tickets/111-void-refund-and-auth_capture-for-authorizenets-cim-gateway#ticket-111-1

include ActiveMerchant::Billing
require 'digest/sha1'

class AuthorizeNetCimResponse < ActiveMerchant::Billing::Response
  def token
    @authorization || 
    (@params['direct_response']['transaction_id'] if @params && @params['direct_response'])
  end
end

ActiveMerchant::Billing::AuthorizeNetCimGateway::Response = AuthorizeNetCimResponse

class ActiveMerchant::Billing::AuthorizeNetCimGateway
# module ActiveMerchant #:nodoc:
#   module Billing #:nodoc:
#     class AuthorizeNetCimGateway < Gateway

  # redefine constant (bleh)
  silence_warnings do
    CIM_TRANSACTION_TYPES = {
      :auth_capture => 'profileTransAuthCapture',
      :auth_only => 'profileTransAuthOnly',
      :capture_only => 'profileTransCaptureOnly',
      # adding this
      :void => 'profileTransVoid',
      :refund => 'profileTransRefund'
    }
  end

  # Create a payment profile
  def store(creditcard, options = {})
    profile = {
      :payment_profiles => {
        :payment => { :credit_card => creditcard }
      }
    }
    profile[:payment_profiles][:bill_to] = options[:billing_address] if options[:billing_address]
    profile[:ship_to_list] = options[:shipping_address] if options[:shipping_address]

    # CIM actually does require a unique ID to be passed in, 
    # either merchant_customer_id or email, so generate it, if necessary
    if options[:billing_id]
      profile[:merchant_customer_id] = options[:billing_id]
    elsif options[:email]
      profile[:email] = options[:email]
    else
      profile[:merchant_customer_id] = Digest::SHA1.hexdigest("#{creditcard.number}#{Time.now.to_i}").first(20)
    end

    #create_customer_profile(:profile => profile)
    create_customer_profile( {
      :ref_id => rand(1_000_000),
      :profile => profile
    })
  end

  # Update an existing payment profile
  def update(billing_id, creditcard, options = {})
    if (response = get_customer_profile(:customer_profile_id => billing_id)).success?
      update_customer_payment_profile(
        :customer_profile_id => billing_id,
        :payment_profile => {
          :customer_payment_profile_id => response.params['profile']['payment_profiles']['customer_payment_profile_id'],
          :payment => {
            :credit_card => creditcard
          }
        }.merge(options[:billing_address] ? {:bill_to => options[:billing_address]} : {})
      )
    else
      response
    end
  end

  # Run an auth and capture transaction against the stored CC
  def purchase(money, billing_id, options = {})
    if (response = get_customer_profile(:customer_profile_id => billing_id)).success?
      create_customer_profile_transaction( options.merge(
        :transaction => { 
          :customer_profile_id => billing_id, 
          :customer_payment_profile_id => response.params['profile']['payment_profiles']['customer_payment_profile_id'], 
          :type => :auth_capture, :amount => amount(money) 
        }
      ))
    else
      response
    end
  end

  # authorize
  def authorize(money, billing_id, options = {})
    if (response = get_customer_profile(:customer_profile_id => billing_id)).success?
      create_customer_profile_transaction( options.merge(
        :transaction => { 
          :customer_profile_id => billing_id, 
          :customer_payment_profile_id => response.params['profile']['payment_profiles']['customer_payment_profile_id'], 
          :type => :auth_only, :amount => amount(money) 
        }
      ))
    else
      response
    end
  end

  # void
  def void(money, trans_id, options = {})
      create_customer_profile_transaction(
        :transaction => { 
          :type => :void,
          :trans_id => trans_id
        }
      )
  end

  # refund (against a previous transaction) (options  { :amount => money })
  def refund(trans_id, options)
    money = options.delete(:amount)
    billing_id = options.delete(:billing_id)
    if (response = get_customer_profile(:customer_profile_id => billing_id)).success?
      create_customer_profile_transaction(
        :transaction => { 
          :customer_profile_id => billing_id, 
          :customer_payment_profile_id => response.params['profile']['payment_profiles']['customer_payment_profile_id'], 
        
          :type => :refund, 
          :trans_id => trans_id,
          :amount => amount(money) 
        }
      )
    else
      response
    end
  end

  # credit (is a refund without the trans_id) 
  # Requires Special Permission, Is not recommended by Authorize.net
  # def credit(money, billing_id)
  #   if (response = get_customer_profile(:customer_profile_id => billing_id)).success?
  #     create_customer_profile_transaction(
  #       :transaction => { 
  #         :customer_profile_id => billing_id, 
  #         :customer_payment_profile_id => response.params['profile']['payment_profiles']['customer_payment_profile_id'], 
  #         :type => :refund, :amount => amount(money) 
  #       }
  #     )
  #   else
  #     response
  #   end
  # end

  # Destroy a customer profile
  def unstore(billing_id, options = {})
    delete_customer_profile(:customer_profile_id => billing_id)
  end

  def create_customer_profile_transaction(options)
    requires!(options, :transaction)
    requires!(options[:transaction], :type)
    case options[:transaction][:type]
      when :void
        requires!(options[:transaction], :trans_id)
      when :refund
        requires!(options[:transaction], :trans_id) &&
          (
            (options[:transaction][:customer_profile_id] && options[:transaction][:customer_payment_profile_id]) ||
            options[:transaction][:credit_card_number_masked] ||
            (options[:transaction][:bank_routing_number_masked] && options[:transaction][:bank_account_number_masked]) 
          )
      when :prior_auth_capture
        requires!(options[:transaction], :amount, :trans_id)
      else
        requires!(options[:transaction], :amount, :customer_profile_id, :customer_payment_profile_id)
    end
    request = build_request(:create_customer_profile_transaction, options)
    commit(:create_customer_profile_transaction, request)
  end
  
  def create_customer_profile_transaction_for_refund(options)
    requires!(options, :transaction)
    options[:transaction][:type] = :refund
    requires!(options[:transaction], :trans_id)
    requires!(options[:transaction], :amount)

    request = build_request(:create_customer_profile_transaction, options)
    commit(:create_customer_profile_transaction, request)
  end
  
  
  def tag_unless_blank(xml, tag_name, data)
    xml.tag!(tag_name, data) unless data.blank? || data.nil?
  end

  def add_transaction(xml, transaction)
    unless CIM_TRANSACTION_TYPES.include?(transaction[:type])
      raise StandardError, "Invalid Customer Information Manager Transaction Type: #{transaction[:type]}"
    end
    
    xml.tag!('transaction') do
      xml.tag!(CIM_TRANSACTION_TYPES[transaction[:type]]) do
        # The amount to be billed to the customer
        case transaction[:type]
          when :void
            tag_unless_blank(xml,'customerProfileId', transaction[:customer_profile_id])
            tag_unless_blank(xml,'customerPaymentProfileId', transaction[:customer_payment_profile_id]) 
            tag_unless_blank(xml,'customerShippingAddressId', transaction[:customer_shipping_address_id]) 
            xml.tag!('transId', transaction[:trans_id])
          when :refund
            #TODO - add support for all the other options fields
            xml.tag!('amount', transaction[:amount])
            tag_unless_blank(xml, 'customerProfileId', transaction[:customer_profile_id])
            tag_unless_blank(xml, 'customerPaymentProfileId', transaction[:customer_payment_profile_id]) 
            tag_unless_blank(xml, 'customerShippingAddressId', transaction[:customer_shipping_address_id]) 
            tag_unless_blank(xml, 'creditCardNumberMasked', transaction[:credit_card_number_masked])
            tag_unless_blank(xml, 'bankRoutingNumberMasked', transaction[:bank_routing_number_masked])
            tag_unless_blank(xml, 'bankAccountNumberMasked', transaction[:bank_account_number_masked])
            xml.tag!('transId', transaction[:trans_id])
          when :prior_auth_capture
            xml.tag!('amount', transaction[:amount])
            xml.tag!('transId', transaction[:trans_id])
          else
            xml.tag!('amount', transaction[:amount])
            xml.tag!('customerProfileId', transaction[:customer_profile_id])
            xml.tag!('customerPaymentProfileId', transaction[:customer_payment_profile_id])
            xml.tag!('approvalCode', transaction[:approval_code]) if transaction[:type] == :capture_only
        end
        add_order(xml, transaction[:order]) if transaction[:order]
      end
    end
  end
  
  def parse_direct_response(response)
    direct_response = {'raw' => response.params['direct_response']}
    direct_response_fields = response.params['direct_response'].split(',')

    #keep this backwards compatible but add new direct response fields using
    #field names from the AIM guide spec http://www.authorize.net/support/AIM_guide (around page 29)
    dr_hash = {
        'message' => direct_response_fields[3],
        'approval_code' => direct_response_fields[4],
        'invoice_number' => direct_response_fields[7],
        'order_description' => direct_response_fields[8],
        'amount' => direct_response_fields[9],
        'transaction_type' => direct_response_fields[11],
        'purchase_order_number' => direct_response_fields[36]
      }
       
      dr_arr = %w(response_code response_subcode response_reason_code response_reason_text
        authorization_code avs_response transaction_id invoice_number description amount
        method transaction_type customer_id first_name last_name company address
        city state zip_code country phone fax email-address ship_to_first_name
        ship_to_last_name ship_to_company ship_to_address ship_to_city ship_to_state 
        ship_to_zip_code ship_to_country tax duty freight tax_exempt purchase_order_number
        md5_hash card_code_response cardholder_authentication_verification_response
        )
      dr_arr.each do |f|
        dr_hash[f] = direct_response_fields[dr_arr.index(f)] 
      end
      direct_response.merge(dr_hash)
  end
  
end


