Rails.application.routes.draw do
  get '/about' => 'about#index'

  devise_for :users
  resources :users, only: :show

  resources :pictures, only: :create
  resources :pictures, only: :destroy

  root to: 'posts#index'
  resources :posts do
    resources :comments
    member do
      put "like", to: "posts#upvote"
      put "dislike", to: "posts#downvote"
    end
  end

  # Annotator.js routes
  get 'annotator/' => 'annotation#root'
  get 'annotator/annotations' => 'annotation#index'
  post 'annotator/annotations' => 'annotation#create'
  get 'annotator/annotations/:id' => 'annotation#read', as: 'annotation_read'
  put 'annotator/annotations/:id' => 'annotation#update'
  delete 'annotator/annotations/:id' => 'annotation#delete'
  get 'annotator/search' => 'annotation#search'

end