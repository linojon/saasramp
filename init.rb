#require 'saasramp'
require 'saasramp/acts_as_subscriber'

# enable acts_as_subscriber
ActiveRecord::Base.class_eval do
  include Saasramp::Acts::Subscriber
end
