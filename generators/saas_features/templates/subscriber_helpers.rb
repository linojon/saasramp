module SubscriberHelpers
  
  # change these as needed by your app
  # e.g. i'm assuming here that User acts_as_subscriber
  
  def create_subscriber( options = {} )
    args = {
      :username => 'subscriber',
      :password => 'secret',
      :password_confirmation => 'secret',
    }.merge( options )
    args[:email] ||= "#{args[:username]}@example.com"
    
    subscriber = User.create!(args)
    # :create syntax for restful_authentication w/ aasm. Tweak as needed.
    # user.activate! 
    subscriber
  end

  def log_in_subscriber
    visit "/login" 
    fill_in("user_session_username", :with => 'subscriber') 
    fill_in("password", :with => 'secret') 
    click_button("Log in")  
  end  
  
  def find_subscriber
    User.find_by_username('subscriber')
  end  
end

World(SubscriberHelpers)