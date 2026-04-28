Rails.application.routes.draw do
  resource  :session
  resources :passwords, param: :token

  namespace :content do
    resources :posts
  end

  get "up" => "rails/health#show", as: :rails_health_check

  root to: redirect("/content/posts")
end
