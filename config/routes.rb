Rails.application.routes.draw do
  resources :guilds, only: [:index, :show, :new, :create]
  resources :players, path: 'p', only: [:index, :show]
  resource :profile, only: [:edit, :update]
  resources :registrations, only: [:create, :destroy]
  resources :scrims, only: [:index]
  resources :streamers, only: [:index]
  resources :tournaments, only: [:index]

  namespace :administration do
    resources :players, only: [:index] do
      resources :checks, only: [:create], controller: 'players/checks'
      resources :invitations, only: [:create], controller: 'players/invitations'
      resources :unchecks, only: [:create], controller: 'players/unchecks'
    end
  end

  devise_for :players, controllers: {
    omniauth_callbacks: 'players/omniauth_callbacks'
  }
end
