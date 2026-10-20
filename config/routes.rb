Rails.application.routes.draw do
  root "assessments#index"
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"
  resources :assessments, only: [:index, :show, :update] do
    get :export, on: :collection, defaults: { format: :csv }
  end
  get "up", to: "rails/health#show", as: :rails_health_check
end
