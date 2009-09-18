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
    subscriber.subscription.next_renewal_on = renewal_text_to_date(text)
    subscriber.subscription.save
  end

  def set_profile_state( subscriber, text )
    profile = subscriber.subscription.profile || subscriber.subscription.build_profile
    case text
    when /no info/
      profile.state = 'no_info'
    when /authorized/, /error/
       # fake it for now, not really on gateway
      params = SubscriptionProfile.example_credit_card_params
      profile.profile_key         = '1' # bogus: 1=success, 2=exception, 3=error on subsequent transactions
      profile.card_first_name     = params[:first_name]
      profile.card_last_name      = params[:last_name]
      profile.card_type           = params[:type]
      profile.card_display_number = 'XXXX-XXXX-XXXX-1'
      profile.card_expires_on     = '2012-10-31'
      if text =~ /error/
        profile.state = 'error'
      else
        profile.state = 'authorized'
      end
      profile.save
    else
      puts 'bad case in set_current_profile_state'
    end
    profile.save
  end

  def renewal_text_to_date(text)
    today = Time.zone.today
    case text
    when /original renewal plus 1 month/
      @original_renewal + 1.month
    when /today/
      today
    when /in 3 days/
      today + 3.days
    when /3 days ago/
      today - 3.days
    when /in 15 days/
      today + 15.days
    when /in 30 days/
      today + 30.days
    when /in 1 month/
      today + 1.month
    when /in 1 year/
      today + 1.year
    when "blank"
      nil
    else
      puts 'bad case in renewal_text_to_date'
    end
  end
end

World(SubscriptionHelpers)
