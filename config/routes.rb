Rails.application.routes.draw do
  resource :profile, only: [:edit, :update]

  devise_for :players, controllers: {
    omniauth_callbacks: 'players/omniauth_callbacks'
  }
end
