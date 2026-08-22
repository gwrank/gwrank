Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :items, only: [:index, :show]
      resources :matches, only: [:create]
      resources :teambuilds, only: [:index, :show, :update, :destroy]
    end
  end

  resource :api_token, only: [:show]
  resources :comments, only: [:create]
  resources :guilds, only: [:index, :show, :new, :create]
  resources :matches, only: [:index, :show, :new, :create, :destroy]
  resources :movies, only: [:create]
  resources :players, path: 'p', only: [:index, :show]
  resource :profile, only: [:edit, :update, :destroy] do
    resources :characters, only: [:new, :create, :destroy], controller: 'profiles/characters'
  end
  resources :registrations, only: [:create, :destroy]
  resources :scrims, only: [:index, :show]
  resource :search, only: [:show]
  resources :statistics, only: [:index]
  resources :streamers, only: [:index]
  resources :tournaments, only: [:index, :show]

  namespace :administration do
    resources :character_claims, only: [:index, :show] do
      member do
        post :approve
        post :reject
      end
    end
    resources :players, only: [:index] do
      resources :checks, only: [:create], controller: 'players/checks'
      resources :invitations, only: [:create], controller: 'players/invitations'
      resources :unchecks, only: [:create], controller: 'players/unchecks'
    end
    resources :tournaments, only: [:new, :create]
  end

  devise_for :players, controllers: {
    omniauth_callbacks: 'players/omniauth_callbacks'
  }

  get 'privacy', to: 'static_pages#privacy'
  get 'terms', to: 'static_pages#terms'

  # Documentation routes
  get '/player', to: 'documentation#player', as: :player_doc
  get '/at', to: 'documentation#at', as: :at_doc
  get '/mat', to: 'documentation#mat', as: :mat_doc
  get '/scrim', to: 'documentation#scrim', as: :scrim_doc
  get '/build', to: 'documentation#build', as: :build_doc
  get '/teambuild', to: 'documentation#teambuild', as: :teambuild_doc

  root to: 'home#index'
end
