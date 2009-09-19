Feature: Subscription
  In order to use subscription based services
	As a subscriber
  I want to maintain my subscription

  Scenario: As a new user, my subscription page says I have a free account
    Given a "free" subscriber is logged in
		When I go to my subscription page
		Then I should see "Free"
		And I should see "(no credit card on file)"
    #And show me the page
  
	Scenario: I have a free account and sign up for a paid plan
		Given a "free" subscriber is logged in
		When I go to my plan page
		#And show me the page
		And I select "basic" from "Plan"
		And I press "Change Plan"
		#And show me the page		
		Then I should be on my subscription page
		And I should see "Basic ($10.00 per month)"
		And I should see "Trial"
		And the subscription should have next renewal in 1 month
		
  Scenario: I add credit card info
		Given a "basic" subscriber who is in trial, with next renewal in 3 days, and profile has no info
		When the subscriber logs in
		And I go to my subscription page
		Then I should see "(no credit card on file)"
		When I press "Update Credit Card"
		And I fill out the credit card form correctly
		And I press "Submit"
		#And show me the page
		Then I should be on my subscription page
		And I should see "Credit card info successfully updated. No charges have been made at this time."
		And I should see "Bogus XXXX-XXXX-XXXX-1 Expires: 2012-10-31"
		And the profile should be "authorized"
	
	Scenario: Subscription is past due, I update credit card info
		Given a "basic" subscriber who is past due, with next renewal 3 days ago, and profile has an error
		When the subscriber logs in
		And I go to my subscription page
		#And show me the page
		Then I should see "There was an error processing your credit card"
		When I press "Update Credit Card"
		And I fill out the credit card form correctly
		And I press "Submit"
		#And show me the page
		Then I should be on my subscription page
		And I should see "Thank you for your payment. Your credit card has been charged $10.00"
		And I should see "Bogus XXXX-XXXX-XXXX-1 Expires: 2012-10-31"
		And the profile should be "authorized"
		And a "charge" transaction should be created
		And the next renewal should be set to "original renewal plus 1 month"
	
	Scenario: I can see my transaction history
		Given a "basic" subscriber who is in trial, with next renewal is today, and profile has no info
		When the subscriber logs in
		And I go to my credit card page
		And I fill out the credit card form correctly
		And I press "Submit"
		Then I should be on my subscription page
		When I follow "History"
		#And show me the page
		Then I should see "Charge $10.00"
		And I should see "Store"
	
	Scenario: I upgrade to a higher cost plan
	  Given a "basic" subscriber who is active, with next renewal in 15 days, and profile is authorized
		When the subscriber logs in
		And I go to my plan page
		And I select "pro" from "Plan"
		And I press "Change Plan"
		#And show me the page		
		Then I should be on my subscription page
		And I should see "Your credit card has been charged $295.00"
		And I should see "Pro"
		And I should see "Active"
		And the subscription should have next renewal in 1 year
		
	Scenario: I cancel my account
	  Given a "basic" subscriber who is active, with next renewal in 15 days, and profile is authorized
		When the subscriber logs in
		And I go to my plan page
		And I follow "I want to cancel my subscription"
	  #And show me the page
		Then I should see "Your subscription has been canceled"
		And I should see "Free"
		And I should see "$-5.00"
