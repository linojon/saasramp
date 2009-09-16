# monkeypatch the gateway
class BraintreeResponse < ActiveMerchant::Billing::Response
  def token
    @params["customer_vault_id"]
  end
end

#ActiveMerchant::Billing::BraintreeGateway::Response = BraintreeResponse
ActiveMerchant::Billing::SmartPs::Response = BraintreeResponse
