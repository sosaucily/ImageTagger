class Order < ActiveRecord::Base
  
  #belongs_to :account
  has_many :line_items
    
  def analyze_videos
    line_items.each do |item|
      item.video.do_analyze(item.quality)
    end
  end
  
end