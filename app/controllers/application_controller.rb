# This is part of the BetterSense Web system
#
# Author::    Jesse Smith  (mailto:js@bettersense.com)
# Copyright:: Copyright (c) 2011 BetterSense

class ApplicationController < ActionController::Base
  protect_from_forgery

  # Function to validate that the account_id matches the account id of the session holder
  # This function will either return nil, or a redirect call.
  # Because any page that calls this should have authentication requirements, we can assume the user is authenticated in some way.
  # Params:
  # +account_id+:: Account ID in question
  # Return: Lambda function of either nil, or a redirect to the user's /account default page.
  def validate_account_id(account_id)
    if ((!admin_signed_in?) and (!session.include? "account_id" or (account_id.to_i != session[:account_id].to_i))) then
      return lambda {
        flash[:alert] = "Sorry, you don't have access to that page."
        redirect_to '/account'
        return true
      }
    else
      return lambda {return nil}
    end
  end
  
  def check_remote_key(key)
    logger.info ("Comparing " + key + " with " + BetterSenseDemo::APP_CONFIG["backend_key"])
    return (BetterSenseDemo::APP_CONFIG["backend_key"] == key)
  end

  # Redirect after login using Devise
  # Params:
  # +resource+:: The object being managed by Devise (User or Admin)
  # Return: URL for redirection after login.  If the user (or admin) had a target destination before being redirected to the auth page, grab that value and return it.
  def after_sign_in_path_for(resource)
    #This method needs the overwritten 'stored_location_for' method below otherwise this method won't run when a user is redirected to the login page from a protected page.
    if (resource.is_a? User)
      logger.info "Login recorded from User with id:" + resource.id.to_s
      #clear_session_data
      setup_session_from_User(resource)
      if (session.include? :user_return_to)
        session.delete :user_return_to #This also returns the value of this session variable, used for redirect
      else
        '/account'
      end
    elsif (resource.is_a? Admin)
      logger.info "Login recorded from Admin with id:" + resource.id.to_s
      '/sysadmin'
    end
  end
  
  # Overwrite this Devise method to redirect properly
  # Params:
  # +resource+:: The object being managed by Devise (User or Admin)
  # Return: nil
  def stored_location_for(resource)
    return nil
  end
  
private

  def current_cart
    Cart.find(session[:cart_id])
  rescue ActiveRecord::RecordNotFound
    cart = Cart.create(:account_id => session[:account_id])
    session[:cart_id] = cart.id
    cart
  end
  
  def reset_cart
    cart = Cart.find(session[:cart_id])
    cart.line_items.each do |item|
      item.cart = nil
      item.save
    end
    cart.line_items = []
    cart.save
  rescue ActiveRecord::RecordNotFound
    cart = Cart.create(:account_id => session[:account_id])
    session[:cart_id] = cart.id
    cart
  end

  #Validate the current session.
  #If Devise says the user is signed in, but they don't have a valid account_id in the session object, add it.
  #I believe this can happen if the rails session timing is different from that of Devise.
  def check_session
    logger.debug "Checking session"
    if (session[:account_id].nil? or session[:account_id] <= 0)
      if (user_signed_in?)
        setup_session_from_User(current_user)
      else
        flash[:alert] = "Error with user session, please try to log in again."
        redirect_to '/'
      end
    end
  end
  
  #Basic values to set up and commands to run upon user login
  def setup_session_from_User(resource)
    session[:account_id] = resource.account_id
    logger.debug "Setting account id to " + resource.account_id.to_s
    cart = Cart.where(:account_id => resource.account_id).first || Cart.create(:account_id => resource.account_id)
    session[:cart_id] = cart.id
  end

  def include_cart
    @cart = current_cart()
  end
  
end
