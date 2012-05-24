class Video < ActiveRecord::Base
  has_many :crowd_images
  #belongs_to :account

  has_attached_file :vid_file
  has_attached_file :thumbnail, :styles => { :thumb => "100x100>" }

  validates :account, :account_exists => true

#Do i need this??
  include VideosHelper
  
  #I'm going to need some kind of status for the videos, so in the polling I know which ones to operate on.
  def send_to_backend
    #Call backend system to make an entry in the backend system for the video
    #Build video parameters for creating new Video
    video_params = {:params=>{:action=>"submit",:display_name=>name||vid_file_file_name, :video_description=>description||"", :account_id=>account_id, :friendly_id=>id, :video_meta_tags=>[]} }
    submit_url = ImageTagger::APP_CONFIG["backend_base_url"] + ImageTagger::APP_CONFIG["backend_video_url"]
    
    response = send_command_to_backend(submit_url, video_params)
    if response.code != 200 then return end

    #Move the video to the backend folder. (Can this be done over HTTP to allow for separate machines?)
    new_video_file_name = id.to_s + vid_file_file_name[vid_file_file_name.length-4..-1]
    
    response = RestClient.post(submit_url + "accept_video", :file_id => new_video_file_name, :video_file => File.new(Rails.root.to_s + ImageTagger::APP_CONFIG["upload_video_dir"] + id.to_s + ImageTagger::APP_CONFIG["upload_video_sub_dir"] + vid_file_file_name, 'rb'))
    
    #logger.info(response.to_s)
    if (response.code != 200)
      logger.error("Transferred Video to backend, but received a failure.  Printing video data: " + self.inspect)
      return
    end
    logger.info("Successfully transfered video to backend system.  Deleting video file.")
    self.vid_file = nil
    self.save
    poll_for_video_status_change
  end
  handle_asynchronously :send_to_backend, :run_at => Proc.new { ImageTagger::APP_CONFIG["send_video_to_backend_seconds"].to_i.seconds.from_now }
  
  #This is an asynchronous background function using Delayed_Job.  Settings follow the method declaration below.
  def poll_for_video_status_change
    #Do a retrieve and see if the status has information that we don't currently have on the video object.
    #If true, update the video (which will give the user different functions on the website, and may fire an email)
    current_status = status || "new" #The default is "new"
    video_params = {:params=>{:action=>"retrieve",:friendly_id=>id} }
    retrieve_url = ImageTagger::APP_CONFIG["backend_base_url"] + ImageTagger::APP_CONFIG["backend_video_url"]
    
    response = send_command_to_backend(retrieve_url, video_params)
    if response.code != 200 then return end
      
    video_data = JSON.load(response.body.to_s)
    new_status = video_data['status']['bettersense_status'].to_s
    
    #logger.info("Current video params = " + video_data.inspect)
    #Set values, but activerecord only updates the object if they have changed
    self.hashstring = video_data['hashstring']
    self.lengthmillis = video_data['length'].to_i
    self.res_x = video_data['width'].to_i
    self.res_y = video_data['height'].to_i
    self.save
    
    #logger.info("Body of retrieve query is: " + video_data.to_s)
    logger.info("Current status is \"" + current_status + "\" and new status is \"" + new_status + "\"")
    if (new_status.nil? || new_status == "")
      poll_for_video_status_change
      return
    end

    if (new_status == "error")
      self.status = new_status
      self.save
      error_message = video_data['status']['error_message'].to_s
      logger.error("Error processing video on backend.  Message: " + error_message)
      return
    end
    
    if (new_status != current_status)
      logger.info("Updating video status with status=\"" + new_status + "\"")
      self.status = new_status
      self.save
    end
    
    #Loop through waiting for a status change.  When it does change, do something
    if (is_processing || is_analyzing)
      poll_for_video_status_change
    elsif (is_complete || is_processed)
      logger.info ("Video is in a stable status, done status polling.")
      if (is_complete)
        enable_reports
      end
    else
      logger.error ("received an unknown video status from backend system " + new_status.to_s)
    end

  end
  handle_asynchronously :poll_for_video_status_change, :run_at => Proc.new { ImageTagger::APP_CONFIG["poll_for_video_status_change_seconds"].to_i.seconds.from_now }
  
  def do_analyze (quality = 'basic')
    #Analyze video
    if (quality.nil? || quality != 'premium')
      quality = 'basic'
    end
    
    if self.is_processing
      logger.info("Video is still processing, so can't order yet.  Creating new Delayed Job")
      do_analyze
      return
    end
    
    video_params = {:params=>{:action=>"analyze",:friendly_id=>id,:quality=>quality} }
    analyze_url = ImageTagger::APP_CONFIG["backend_base_url"] + ImageTagger::APP_CONFIG["backend_video_url"]
    
    response = send_command_to_backend(analyze_url, video_params)
    if response.code != 200 then return end
    logger.info("Sending video for analysis: " + name + " with quality " + quality)
    #Set status of video to be something like "analyzing," so the "add to cart" button goes away right away.
    #Should we also trigger the poll_for_change now? or does that happen after it has completed analysis?
  end
  handle_asynchronously :do_analyze, :run_at => Proc.new { ImageTagger::APP_CONFIG["analyze_video_seconds"].to_i.seconds.from_now }
  
  def delete_from_backend()
    #Delete video from backend, and then from Rails
    
    if (is_complete || is_processed) then
      video_params = {:params=>{:action=>"destroy",:friendly_id=>id} }
      destroy_url = ImageTagger::APP_CONFIG["backend_base_url"] + ImageTagger::APP_CONFIG["backend_video_url"]
    
      response = send_command_to_backend(destroy_url, video_params)
      if response.code != 200 then return end
      logger.info("Deleting video: " + name)
    
      self.destroy
    else
      #This video isn't ready to be deleted, so let's hold off
      logger.info("Video isn't ready to be deleted, so spinning on delayed job: " + name)
      delete_from_backend
    end
  end
  handle_asynchronously :delete_from_backend, :run_at => Proc.new { ImageTagger::APP_CONFIG["delete_from_backend_seconds"].to_i.seconds.from_now }
  
  def ready_to_order
    !is_processing || status == "processing"
  end
  
  def available_reports
    return [] unless is_complete
    
    video_report_dir = Rails.root.to_s + ImageTagger::APP_CONFIG["report_directory"] + hashstring
    if !File.directory?(video_report_dir) then
      logger.error("Video Report Directory trying to be accessed, but it doesn't exist: " + hashstring)
      return []
    end
    Dir.chdir(video_report_dir)

    reports = Dir.glob("*.txt")
    reports << Dir.glob("*.xml")
    reports.flatten
  end
  
  def is_complete
    return (status == "complete")
  end
  
  def is_processed
    return (status == "processed")
  end
  
  def is_processing
    return (status == "new" || status == "created" || status == "processing")
  end
  
  def is_analyzing
    return (status == "ordered" || status == "analyzing" || status == "analyzed")
  end
  
  private
  
  def enable_reports
    #Transfer the reports to a local folder for the user to download and be accessible from a javascript API
    logger.info("running enable_reports")
    basic_url = ImageTagger::APP_CONFIG["backend_base_url"] + ImageTagger::APP_CONFIG["backend_report_url"] + hashstring + "/reports/" + name + "_basic.txt"
    premium_url = ImageTagger::APP_CONFIG["backend_base_url"] + ImageTagger::APP_CONFIG["backend_report_url"] + hashstring + "/reports/" + name + "_premium.txt"
    basic_url_xml = ImageTagger::APP_CONFIG["backend_base_url"] + ImageTagger::APP_CONFIG["backend_report_url"] + hashstring + "/reports/" + name + "_basic.xml"
    premium_url_xml = ImageTagger::APP_CONFIG["backend_base_url"] + ImageTagger::APP_CONFIG["backend_report_url"] + hashstring + "/reports/" + name + "_premium.xml"

    video_report_dir = Rails.root.to_s + ImageTagger::APP_CONFIG["report_directory"] + hashstring
    begin
      Dir.mkdir(video_report_dir)
    rescue
      logger.info ("Report Directory " + hashstring + " already exists")
    end

    response = send_command_to_backend(basic_url)
    begin
      open(video_report_dir + "/" + name + "_basic.txt", "wb") { |file|
        file.write(response.body.to_s)
      }
    rescue
      logger.error ("Couldn't write report_basic file!")
    end
    
    response = send_command_to_backend(premium_url)
    begin
      open(video_report_dir + "/" + name + "_premium.txt", "wb") { |file|
        file.write(response.body.to_s)
      }
    rescue
      logger.error ("Couldn't write report_premium file!")
    end

    response = send_command_to_backend(basic_url_xml)
    begin
      open(video_report_dir + "/" + name + "_basic.xml", "wb") { |file|
        file.write(response.body.to_s)
      }
    rescue
      logger.error ("Couldn't write report_basic file!")
    end
    
    response = send_command_to_backend(premium_url_xml)
    begin
      open(video_report_dir + "/" + name + "_premium.xml", "wb") { |file|
        file.write(response.body.to_s)
      }
    rescue
      logger.error ("Couldn't write report_premium file!")
    end
    
  end
  
  def send_command_to_backend (url, params = nil)
    begin
      logger.info("Submitting video to backend with command: " + url + (params.to_json || "") )
      if (params.nil?)
        response = RestClient.get(url)
      else
        response = RestClient.get(url, params)
      end
      if (response.code != 200)
        logger.error("Submitted Video to backend, but received a failure.  Printing video data: " + self.inspect)
      end
    rescue
      logger.error ("Error thrown when making HTTP call to backend")
      return false
    end
    return response
  end
  
  def post_command_to_backend (url, params)
    logger.info("Submitting video to backend with command: " + url + params.to_json)
    begin
      response = RestClient.get(url, params)
      if (response.code != 200)
        logger.error("Submitted Video to backend, but received a failure.  Printing video data: " + self.inspect)
      end
    rescue
      logger.error ("Error thrown when making HTTP call to backend")
      return false
    end
    return response
  end
  
end
