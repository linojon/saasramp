module SubscriptionHelpers

  def set_subscription_state( subscriber, text )
    unless ['pending', 'free', 'trial', 'active', 'past due'].include? text
      puts "bad case in set_current_subscription_text"
      return
    end
    subscriber.subscription.state = text.gsub(' ','_')
    # past due will have a balance due, so set it to the plan rate
    subscriber.subscription.balance = subscriber.subscription.plan.rate if subscriber.subscription.past_due?
    subscriber.subscription.save
  end

  def set_renewal( subscriber, text )
    subscriber.subscription.next_renewal_on = text_to_date(text)
    subscriber.subscription.save
  end

  def set_profile_state( subscriber, text )
    profile = subscriber.subscription.profile || subscriber.subscription.build_profile
    case text
    when /no info/
      profile.state = 'no_info'
    when /authorized/, /error/
      params = SubscriptionProfile.example_credit_card_params
      profile.credit_card = params
  	  #profile.request_ip = request.remote_ip
  	  ok = profile.save
  	  ok.should be_true
      if text =~ /error/
        profile.state = 'error'
        profile.save
      end
    else
      puts 'bad case in set_current_profile_state'
    end
    profile.save
  end

  def text_to_date(text)
    today = Time.zone.today
    case text
    when /original renewal plus 1 month/
      @original_renewal + 1.month
    when /today/
      today
    when /in (\d+) days/
      today + ($1).to_i.days
    when /(\d+) days ago/
      today - ($1).to_i.days
    when /in 1 month/
      today + 1.month
    when /in 1 year/
      today + 1.year
    when "blank"
      nil
    else
      puts 'bad case in text_to_date'
    end
  end
end

World(SubscriptionHelpers)
