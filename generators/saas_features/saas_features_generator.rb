class SaasFeaturesGenerator < Rails::Generator::Base

  def manifest
    record do |m|
      m.directory   'features'
      m.file        'subscription.feature',       'features/subscription.feature'
      
      m.directory   'features/step_definitions'
      m.file        'subscription_steps.rb',      'features/step_definitions/subscription_steps.rb'
      
      m.directory   'features/support'
      m.file        'subscription_helpers.rb',    'features/support/subscription_helpers.rb'
      m.file        'subscriber_helpers.rb',      'features/support/subscriber_helpers.rb'

# cancel
    end
  end
end
