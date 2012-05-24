ImageTagger::Application.routes.draw do

  resources :orders

  resources :carts
  
  match "carts/:cart_id/add_item", :controller => 'carts', :action => 'add_item'
  match "carts/:cart_id/remove_item", :controller => 'carts', :action => 'remove_item'
  match "carts/:cart_id/clear_items", :controller => 'carts', :action => 'clear_items'
  
  #VIDEOS
  match "videos/:video_id/crowd_images/:id/:action", :controller => 'crowd_images', :action => /[a-zA-Z]+/i
  match "videos/:video_id/order", :controller => 'videos', :action => 'order'
  match "videos/:video_id/update_status", :controller => 'videos', :action => 'update_status'
  match "videos/:id/reports", :controller => 'videos', :action => 'reports'
  match "videos/:id/reports/:report_name", :controller => 'videos', :action => 'download_report'
  match "videos/refresh_videos", :controller => 'videos', :action => 'refresh_videos'
  
  #ImageTag
  match "imagetag", :controller => 'imagetag', :action => 'index'
  match "imagetag/:iqeinfo_id", :controller => 'imagetag', :action => 'update'
  get "imagetag/list"
  get "imagetag/crowdProcess"
  
  #HOME
  get "home/index"
  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  root :to => "home#index"

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id))(.:format)'
end
