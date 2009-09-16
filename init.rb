# depends on gems
require 'activemerchant'
require 'money'
require 'state_machine'

require 'saasramp'
require 'saasramp/acts_as_subscriber'

ActiveRecord::Base.class_eval do
  include Saasramp::Acts::Subscriber
end
