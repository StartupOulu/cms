Rails.application.routes.draw do
  resource  :session
  resources :passwords, param: :token

  namespace :content do
    resources :posts do
      resource :publication, only: [ :destroy ], controller: "posts/publications"
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

  get "git_status" => "git_status#show", as: :git_status

  get "up" => "rails/health#show", as: :rails_health_check

  root to: redirect("/content/posts")
end
