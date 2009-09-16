require File.expand_path(File.dirname(__FILE__) + "/lib/insert_commands.rb")
class SubscriptionScaffoldGenerator < Rails::Generator::NamedBase

  def manifest
    record do |m|
      m.directory   'app/controllers'
      m.file        'subscriptions_controller.rb',  'app/controllers/subscriptions_controller.rb'
      
      m.directory   'app/views/subscriptions'
      m.file        'credit_card.html.erb'          'app/views/subscriptions/credit_card.html.erb'
      m.file        'edit.html.erb'                 'app/views/subscriptions/edit.html.erb'
      m.file        'history.html.erb'              'app/views/subscriptions/history.html.erb'
      m.file        'show.html.erb'                 'app/views/subscriptions/show.html.erb'

      m.route_resource_x :subscriptions, :member => { :credit_card => :get, :store_credit_card => :post, :history => :get, :cancel => :get }
      
  end
end
