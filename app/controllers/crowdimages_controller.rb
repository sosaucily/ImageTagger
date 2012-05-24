class CrowdImagesController < ApplicationController

  def processme
    @video = Video.find(params[:video_id])
    logger.debug "Process ME called!"
    @crowd_image = @video.CrowdImages.find(params[:id])
    #add_data_to_image(@crowd_image, params[:qid_data])
    #when ready to test, replace everything below, except for the redirect, with the above line.  Or maybe not, because of data format issues. Check application_controller method.
    qid_data = params[:qid_data]
    logger.debug qid_data
    labels = ""
    qid_data.each do |qid|
      labels += qid[:labels] + " | "
    end
    color = qid_data[0][:color]
    @crowd_image.matcheditem = labels
    @crowd_image.colors = color
    @crowd_image.save
    redirect_to videos_url+'/' + params[:video_id].to_s + '/CrowdImages/' + params[:id]
  end


  def show
    @video = Video.find(params[:video_id])
    @crowd_image = @video.CrowdImages.find(params[:id])
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @crowd_image }
    end
  end

  def index
    @video = Video.find(params[:video_id])
    @crowd_images = @video.CrowdImages.order.paginate :page => params[:page], :per_page => 20 

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @crowd_images }
      format.js
    end
  end

  def edit
    @video = Video.find(params[:video_id])
    @crowd_image = @video.CrowdImages.find(params[:id])
  end

  # PUT /videos/1/CrowdImages/1
  # PUT /videos/1/CrowdImages/1.xml
  def update
    @video = Video.find(params[:video_id])
    @crowd_image = @video.CrowdImages.find(params[:id])

    respond_to do |format|
      if @crowd_image.update_attributes(params[:crowd_image])
        logger.info 'Updating crowd_image with id ' + params[:id].to_s
        format.html { redirect_to(videos_path + "/" + @crowd_image.video_id.to_s + '/CrowdImages/' + @crowd_image.id.to_s, :notice => 'crowd_image was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @ieqinfo.errors, :status => :unprocessable_entity }
      end
    end
  end

  def create
     logger.info 'Processing Images for a video'
    @video = Video.find(params[:video_id])
#    @crowd_image = @video.CrowdImages.create(params[:crowd_image])
    processResults = process_video(@video)
    logger.info 'Results from processing is ' + processResults
    redirect_to video_path(@video)
  end

end
