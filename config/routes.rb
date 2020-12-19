Rails.application.routes.draw do
  resource :profile, only: [:edit, :update]
  resources :registrations, only: [:create, :destroy]

  namespace :administration do
    resources :players, only: [:index] do
      resources :checks, only: [:create], controller: 'players/checks'
      resources :invitations, only: [:create], controller: 'players/invitations'
      resources :unchecks, only: [:create], controller: 'players/unchecks'
    end
  end

  devise_for :admins
  devise_for :players, controllers: {
    omniauth_callbacks: 'players/omniauth_callbacks'
  }
end
