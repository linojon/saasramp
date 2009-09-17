# this generator bootstraps a Rails project for use with SaasRamp
require File.expand_path(File.dirname(__FILE__) + "/lib/insert_commands.rb")
class SaasrampGenerator < Rails::Generator::Base
  def manifest
    record do |m|
      m.directory 'config'
      m.file      'subscription.yml',                     'config/subscription.yml'

      m.directory 'db'
      m.file      'subscription_plans.yml',               'db/subscription_plans.yml'
      
      m.directory 'config/initializers/active_merchant'
      m.file      'active_merchant/bogus.rb',             'config/initializers/active_merchant/bogus.rb'
      m.file      'active_merchant/braintree.rb',         'config/initializers/active_merchant/braintree.rb'
      m.file      'active_merchant/authorizenetcim.rb',   'config/initializers/active_merchant/authorizenetcim.rb'
      
      m.insert_into 'app/controllers/application_controller.rb', 'filter_parameter_logging :credit_card'       
    end
  end
end
