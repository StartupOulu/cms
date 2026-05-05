Rails.application.routes.draw do
  resource  :session
  resources :passwords, param: :token
  resource  :password_change, only: [ :edit, :update ]
  get "users/credentials", to: "users#credentials", as: :user_credentials
  resources :users, only: [ :index, :new, :create ]

  namespace :content do
    resources :posts do
      resource :publication, only: [ :create, :destroy ], controller: "posts/publications"
      resource :autosave,    only: [ :update ],  controller: "posts/autosaves"
      resource :cover_image, only: [ :update, :destroy ], controller: "posts/cover_images"
      resources :images,     only: [ :create ],  controller: "posts/images"
      resource :preview,     only: [ :show ],    controller: "posts/previews"
    end

    resources :events do
      resource :publication, only: [ :create, :destroy ], controller: "events/publications"
      resource :cover_image, only: [ :update, :destroy ], controller: "events/cover_images"
      resource :preview,     only: [ :show ],             controller: "events/previews"
    end
  end

  resource :publish_failure_acknowledgments, only: [ :create ]

  get "git_status" => "git_status#show", as: :git_status

  get "up" => "rails/health#show", as: :rails_health_check

  root to: "dashboard#index"
end
