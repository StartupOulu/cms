Rails.application.routes.draw do
  resource  :session
  resources :passwords, param: :token

  namespace :content do
    resources :posts
  end

  get "git_status" => "git_status#show", as: :git_status

  get "up" => "rails/health#show", as: :rails_health_check

  root to: redirect("/content/posts")
end
