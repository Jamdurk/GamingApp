Rails.application.routes.draw do
  get "clips/new"
  get "clips/create"
    root "pages#home"
   
     get "up" => "rails/health#show", as: :rails_health_check
   
     # Render dynamic PWA files from app/views/pwa/*
     get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
     get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
   
    resources :recordings, only: [:index, :show, :new, :create] do
       resources :clips, only: [:new, :create]
    end
   end