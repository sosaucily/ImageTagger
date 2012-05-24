class VideosController < ApplicationController

  #before_filter :authenticate_user!, :only => ['create']
  skip_before_filter :verify_authenticity_token, :only => ['update']
  before_filter :authenticate_admin!, :only => ['new','edit']
  #before_filter :check_session, :except => ['show','index','new']
  #Mime::Type.register "image/png", :png
  
  # GET /videos
  # GET /videos.xml
  def index
    #@videos = Video.find_all_by_account_id(session[:account_id])
    @videos = Video.all
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @videos }
      format.json { render :json => @videos }
    end
  end

  # GET /videos/1
  # GET /videos/1.xml
  def show
    @video = Video.find(params[:id])
    #The next line are a security to validate that the object being shown is owned by the current session holder.
    if (!validate_account_id(@video.account_id).call().nil?) then return end
    @nac_id = @video.getKalturaIDByName(@video.name).to_s
    respond_to do |format|
      format.html # show.html.erb
      format.js
      format.xml  { render :xml => @video }
      format.json { render :json => @video }
    end
  end

  # GET /videos/new
  # GET /videos/new.xml
  def new
    @video = Video.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @video }
    end
  end

  # GET /videos/1/edit
  def edit
    @video = Video.find(params[:id])
    #The next line are a security to validate that the object being shown is owned by the current session holder.
    if !validate_account_id(@video.account_id).call().nil? then return end
    @video
  end

  # POST /videos
  # POST /videos.xml
  def create
    #If Admin is creating the video (which is how this is done now) the account for the video should be the one selected on the page, not the one from the current session.
    
    logger.info ("creating video and using session info of " + session.to_s)
    if (params[:video_source] == "flash_module") then
      update_params = { :video => { "vid_file" => params["Filedata"], "name" => params["name"], "description" => params["description"]} }
      @video = Video.new(update_params[:video])
      @video.account_id = params[:source_account_id].to_i
      @video.viewable = true
      logger.info ("creating video with params: " + @video.inspect)
      if @video.save
        render :nothing => true, :status => :ok
        @video.send_to_backend
        return true
      end
    else
      @video = Video.new(params[:video])
      @video.account_id = session[:account_id]
    end

    logger.info('Current account_id: ' + @video.account_id.to_s)
    
    respond_to do |format|
      if @video.save
        format.html { redirect_to(@video, :notice => 'Video was successfully created.') }
        format.xml  { render :xml => @video, :status => :created, :location => @video }
        format.json { render :json => @video, :status => :created, :location => @video }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @video.errors, :status => :unprocessable_entity }
        format.json { render :json => @video.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /videos/1
  # PUT /videos/1.xml
  def update
    logger.info("remote" + params["remote_key"].to_s)
    if (params.has_key?("remote_key") && check_remote_key(params["remote_key"]) )
      logger.info "Updating video thumbnail from backend"
      @video = Video.find(params[:id])
      @video.thumbnail = params[:thumbnail]
      respond_to do |format|
        if @video.save
          format.html  { head :ok }
        else
          format.html { head :bad_request }
        end
      end
    else
      verify_authenticity_token
      authenticate_admin!
      @video = Video.find(params[:id])
      #The next line are a security to validate that the object being shown is owned by the current session holder.
      if !validate_account_id(@video.account_id).call().nil? then return end
      respond_to do |format|
        if @video.update_attributes(params[:video])
          logger.info 'Updating Video with id ' + params[:id].to_s
          format.html { redirect_to(@video, :notice => 'Video was successfully updated.') }
          format.xml  { head :ok }
        else
          format.html { render :action => "edit" }
          format.xml  { render :xml => @video.errors, :status => :unprocessable_entity }
        end
      end
    end
  end

  # DELETE /videos/1
  # DELETE /videos/1.xml
  def destroy
    @video = Video.find(params[:id])
    #The next line are a security to validate that the object being shown is owned by the current session holder.
    if !validate_account_id(@video.account_id).call().nil? then return end
    @video.viewable = false
    @video.save
    @video.delete_from_backend() #This calls     @video.destroy
    session_id = session[:account_id].to_i
    @videos = Video.where("account_id = ? AND viewable = ?", session_id, true).order("created_at desc")
    @cart = current_cart
    if (bad_item = @cart.line_items.where(:video_id => params[:id]).first) then
      bad_item.destroy()
    end
    respond_to do |format|
      format.html { redirect_to(videos_url) }
      format.xml  { head :ok }
      format.js   { render :partial => 'shared/refresh_videos',  :layout => false } #, :notice => 'XXX was successfully updated.' } }
    end
  end
  
  # GET /videos/1/order
  def order
    @video = Video.find(params[:video_id])
    
    respond_to do |format|
      format.js
    end
  end
  
  # GET /videos/1/update_status
  def update_status
    @video = Video.find(params[:video_id])
    page_status = params[:video_page_status]
    @cart = current_cart
    #Only need to update the page (via js) if the status of the video has changed
    #This doesn't work on the page... Can't figure out the JS
    #logger.debug "Comparing status=" + @video.status + " with page status=" + page_status
    #if @video.status == page_status then
    #  return head :ok
    #else
    #  logger.debug "They are different, so refreshing video thumb"
    respond_to do |format|
      format.js
    end
    #end
  end
  
  #GET /videos/1/reports
  def reports
    @video = Video.find(params[:id])
    #The next line are a security to validate that the object being shown is owned by the current session holder.
    if !validate_account_id(@video.account_id).call().nil? then return end

    @reports = @video.available_reports()
    
    respond_to do |format|
      format.html #show_reports
    end
  end
  
  def download_report
    @video = Video.find(params[:id])
    requested_format = params[:requested_format].to_s
    report_name = params[:report_name] + "." + requested_format
    #The next line are a security to validate that the object being shown is owned by the current session holder.
    if !validate_account_id(@video.account_id).call().nil? then return end
    
    report_filename = Rails.root.to_s + BetterSenseDemo::APP_CONFIG["report_directory"] + @video.hashstring + "/" + report_name

    #XSendFileAllowAbove on - apache  - http://www.therailsway.com/2009/2/22/file-downloads-done-right/
    send_file report_filename, :type=>"application/txt", :x_sendfile=>true
  end
  
  
  def refresh_videos
    session_id = session[:account_id]
    @videos = Video.where("account_id = ? AND viewable = ?", session_id, true).order("created_at desc")
    @cart = current_cart
    respond_to do |format|
      format.js {render :partial => 'shared/refresh_videos',  :layout => false } #, :notice => 'XXX was successfully updated.' }
    end
  end
  
end
