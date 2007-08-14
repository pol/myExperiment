ActionController::Routing::Routes.draw do |map|
  map.resources :forums, :topics, :posts, :monitorship, :moderatorships
  map.resources :posts, :name_prefix => 'all_', :collection => { :search => :get }

  %w(forum).each do |attr|
    map.resources :posts, :name_prefix => "#{attr}_", :path_prefix => "/#{attr.pluralize}/:#{attr}_id"
  end
  
  map.resources :forums do |forum|
    forum.resources :moderatorships, :controller => :moderators
    forum.resources :topics do |topic|
      topic.resources :posts
      topic.resource :monitorship, :controller => :monitorships
    end
  end

# screws up default / defined by the application    
#  map.forum_home '', :controller => 'forums', :action => 'index'
end