class SubscriptionsController < ApplicationController
  before_filter :login_required
  before_filter :find_subscription

  def show    
  end  

  # edit to change plans
  def edit
    @allowed_plans = @subscription.allowed_plans
  end

  def update
  end

  def cancel
  end

  # could put these in separate controllers, but keeping it simple for now
	def credit_card
	  @profile = @subscription.profile
	end
	
	def store_credit_card
	  @profile = @subscription.profile
	  @profile.credit_card = params[:profile][:credit_card]
	  @profile.request_ip = request.remote_ip
	  if @profile.save
	    if @subscription.past_due? && @subscription.renew
	      flash[:notice] = "Thank you for your payment. Your credit card has been charged #{@subscription.latest_transaction.amount.format}"
      else
	      flash[:notice] = "Credit card info has been securely stored. No charges have been made at this time."  
      end
	    redirect_to subscription_path(:current)
    else
      render :action => 'credit_card'
    end
	end
	
	def history
	  @transactions = @subscription.transactions
	end
	
  private

  def find_subscription
    @subscription = current_user.subscription
  end
end
