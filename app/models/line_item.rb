class LineItem < ActiveRecord::Base
  belongs_to :cart
  belongs_to :video
  belongs_to :order
  
  def get_price
    cost_per_sec = (ImageTagger::APP_CONFIG["#{self.quality || 'basic'}_cost_per_min"].to_f / 60)
    sprintf "%.2f", ( (self.video.lengthmillis / 1000).to_i.to_f * cost_per_sec)
  end
  
end