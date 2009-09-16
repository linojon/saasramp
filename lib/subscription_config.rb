class SubscriptionConfig  
  def self.load
    config_file = File.join(Rails.root, "config", "subscription.yml")

    if File.exists?(config_file)
      text = ERB.new(File.read(config_file)).result
      hash = YAML.load(text)
      config = hash.stringify_keys[Rails.env]
      config.keys.each do |key|
        cattr_accessor key
        send("#{key}=", config[key])
      end
    end
  end
  
  # this is initialized to an instance of ActiveMerchant::Billing::Base.gateway
  cattr_accessor :gateway
  
  def self.bogus?
    gateway.is_a? ActiveMerchant::Billing::BogusGateway
  end
  
  def self.mailer
    @mailer ||= mailer_class.constantize
  end
  
end
SubscriptionConfig.load