class Cart < ActiveRecord::Base
  
    #belongs_to :account
    has_many :line_items
    
    def total_price
      total_price = 0.0
      line_items.each do |item|
        total_price += item.get_price().to_f
      end
      sprintf "%.2f", total_price        
    end
    
end
