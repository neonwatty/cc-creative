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

  # Plugin extension routes
  resources :extensions, only: [ :index, :show ] do
    member do
      post :install
      delete :uninstall
      patch :enable
      patch :disable
      patch :configure
      get :status
      get :health
      post :execute
      get :documentation
      patch :update
    end

    collection do
      get :installed
      get :marketplace
      post :bulk_install
    end
  end

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

    # Command execution routes
    resources :commands, only: [ :create ]

    # Collaboration routes
    scope path: "collaboration", as: "collaboration" do
      post "start", to: "collaboration#start"
      post "join", to: "collaboration#join"
      delete "leave", to: "collaboration#leave"
      post "lock", to: "collaboration#lock"
      delete "unlock", to: "collaboration#unlock"
      get "locks/:lock_id", to: "collaboration#lock_status", as: "lock_status"
      get "permissions", to: "collaboration#permissions"
      post "presence", to: "collaboration#presence"
      post "typing", to: "collaboration#typing"
      post "reconnect", to: "collaboration#reconnect"
      post "operation", to: "collaboration#operation"
      get "status", to: "collaboration#status"
      get "users", to: "collaboration#users"
      delete "terminate", to: "collaboration#terminate"
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

  # Health check and monitoring routes
  get "health" => "health#show", as: :health_check
  get "health/liveness" => "health#liveness", as: :liveness_check
  get "health/readiness" => "health#readiness", as: :readiness_check

  # Metrics and monitoring endpoints
  get "metrics" => "metrics#show", as: :metrics
  get "metrics/prometheus" => "metrics#prometheus", as: :prometheus_metrics
  
  # Admin analytics dashboard
  namespace :admin do
    resources :analytics, only: [ :index ] do
      collection do
        get :users
        get :performance
        get :errors
        get :system
        get :export
      end
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "welcome#index"
end
