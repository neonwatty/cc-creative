Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resources :users, only: [ :new, :create ]
  get "confirm_email/:token", to: "users#confirm_email", as: :confirm_email

  # OAuth routes
  get "auth/:provider/callback", to: "sessions#omniauth"
  get "auth/failure", to: "sessions#omniauth_failure"

  # Cloud integrations
  resources :cloud_integrations, only: [ :index, :new, :destroy ] do
    collection do
      get "google/callback", to: "cloud_integrations#google_callback"
      get "dropbox/callback", to: "cloud_integrations#dropbox_callback"
      get "notion/callback", to: "cloud_integrations#notion_callback"
    end

    resources :cloud_files, only: [ :index, :show ] do
      member do
        post :import
      end

      collection do
        post :export
      end
    end
  end

  # User profile routes (authenticated users only)
  resource :profile, only: [ :show, :edit, :update ] do
    member do
      get :password
      patch :update_password
    end
  end
  get "welcome/index"

  # Document management routes
  resources :documents do
    member do
      post :duplicate
      patch :autosave
    end

    # Nested context items
    resources :context_items do
      collection do
        post :reorder
        get :search
      end
    end

    # Nested sub agents
    resources :sub_agents do
      member do
        post :activate
        post :complete
        post :pause
        post :merge
      end

      # Nested sub agent messages
      resources :messages, controller: "sub_agent_messages", as: "sub_agent_messages" do
        collection do
          post :create
        end
      end
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "welcome#index"
end
