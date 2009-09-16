class User < ActiveRecord::Base
  acts_as_subscriber
  
  attr_accessor :password, :password_confirmation
end