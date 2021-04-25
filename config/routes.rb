Rails.application.routes.draw do
  resources :comments, only: [:create]
  resources :guilds, only: [:index, :show, :new, :create]
  resources :matches, only: [:show]
  resources :players, path: 'p', only: [:index, :show]
  resource :profile, only: [:edit, :update] do
    resources :characters, only: [:new, :create, :destroy], controller: 'profiles/characters'
  end
  resources :registrations, only: [:create, :destroy]
  resources :scrims, only: [:index]
  resource :search, only: [:show]
  resources :statistics, only: [:index]
  resources :streamers, only: [:index]
  resources :tournaments, only: [:index, :show]

  namespace :administration do
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
end
