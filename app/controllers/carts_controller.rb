class CartsController < ApplicationController

  #Cart creation happens automatically through the sessioning system
  before_filter :include_cart, :except => ['destroy']
  
  def index
    respond_to do |format|
      format.html { redirect_to (root_url) }
    end
  end

  # GET /cart/1
  # GET /cart/1.xml
  def show
    @show_clear = (params[:show_clear] == "true")
    respond_to do |format|
      format.html # show.html.erb
      format.js {render :partial => 'shared/refresh_cart',  :layout => false } #, :notice => 'Ad was successfully updated.' }
    end
  end

  def destroy
  end

  def add_item
    #if (params[:cart_id] != session[:cart_id])
    if (!@cart.line_items.where(:video_id => params[:video_id]).empty?) then
      @cart_error = "Videos can only be added to the cart once."
    elsif !Video.find(params[:video_id]).ready_to_order then
      @cart_error = "Please wait until the video is done processing to order.  This should not take more than a few more minutes."
    else
      @cart.line_items.create(:quality => params[:quality], :video_id => params[:video_id])
    end
    respond_to do |format|
      format.js {render :partial => 'shared/refresh_cart', :layout => false } #, :notice => 'Ad was successfully updated.' }
    end
  end
  
  def remove_item
    @cart.line_items.find(params[:item_id]).destroy()
    respond_to do |format|
      format.js {render :partial => 'shared/refresh_cart', :layout => false } #, :notice => 'Ad was successfully updated.' }
    end
  end
  
  def clear_items
    @cart.line_items.each do |item|
      item.destroy()
    end
    #reloading cart to reflect the clear
    @cart = current_cart()
    respond_to do |format|
      format.js {render :partial => 'shared/refresh_cart', :layout => false } #, :notice => 'Ad was successfully updated.' }
    end
  end
end
