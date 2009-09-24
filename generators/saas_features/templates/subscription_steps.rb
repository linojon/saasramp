Given /^a "(.*)" subscriber$/ do |plan|
  reate_subscriber( :username => 'subscriber', :subscription_plan => plan )
end

Given /^a "(.*)" subscriber is logged in$/ do |plan|
  create_subscriber( :username => 'subscriber', :subscription_plan => plan )
  log_in_subscriber
end

Given /^a "(.*)" subscriber who is (in trial|active|past due|expired), with next renewal (.*), and profile (has no info|is authorized|has an error)$/ do |plan, subs_state, date_text, profile_state |
	#Example: Given a "basic" subscriber who is in trial, next renewal is in 3 days, and profile has no info
  subscriber = create_subscriber( :username => 'subscriber', :subscription_plan => plan )
  set_subscription_state( subscriber, subs_state )
  set_renewal( subscriber, date_text )
  set_profile_state( subscriber, profile_state )
  # beware this is not safe in all scenarios
  @original_renewal = subscriber.subscription.next_renewal_on
end

When /^the subscriber logs in$/ do
  log_in_subscriber
end

When /^I fill out the credit card form (correctly|with errors|with invalid card)$/ do |what|
  case what
  when 'correctly'
    params = SubscriptionProfile.example_credit_card_params
  when 'with errors'
    params = SubscriptionProfile.example_credit_card_params( :first_name => '')
  when 'with invalid card'
    params = SubscriptionProfile.example_credit_card_params( :number => '2')
  else
    puts 'step error: unknown "what"'
  end
  params.each do |field, value|
    name = "profile_credit_card_#{field}" #assuming view as form_for :profile ... form.feldsfor :credit_card
    begin
      select value, :from => name
    rescue
      fill_in name, :with => value
    end
  end
end

Then /^the subscription should be a "(.*)" plan$/ do |plan|
  subscriber = find_subscriber
  subscriber.subscription_plan.name.should == plan
end

Then /^the subscription should be in a "(.*)" state$/ do |state|
  subscriber = find_subscriber
  subscriber.subscription.state.should == state
end
  
Then /^the subscription should have next renewal (.*)$/ do |value|
  subscriber = find_subscriber
  subscriber.subscription.next_renewal_on.should == renewal_text_to_date(value)
end

Then /^the profile should be "(no info|authorized|error)"$/ do |state|
  subscriber = find_subscriber
  subscriber.subscription.profile.state.to_s.should == state.downcase
end

Then /^a "(validate|store|update|unstore|charge|credit|refund)" transaction should be created$/ do |action|
  subscriber = find_subscriber
  subscriber.subscription.latest_transaction.action.should == action
end

Then /^the next renewal should be set to "(.*)"$/ do |text|
  subscriber = find_subscriber
  subscriber.subscription.next_renewal_on.should == renewal_text_to_date(text)
end

