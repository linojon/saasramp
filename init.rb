require 'acts_as_subscriber'

ActiveRecord::Base.class_eval do
  include Saasramp::Acts::Subscriber
end
