# monkeypatch the gateway
include ActiveMerchant::Billing

class BraintreeResponse < ActiveMerchant::Billing::Response
  def token
    @params["customer_vault_id"]
  end
end

begin
  # HEAD
  ActiveMerchant::Billing::SmartPs::Response = BraintreeResponse
rescue NameError
  # 1.4.2
  ActiveMerchant::Billing::BraintreeGateway::Response = BraintreeResponse
end