Rails.application.routes.draw do
  devise_for :players, controllers: {
    omniauth_callbacks: 'players/omniauth_callbacks'
  }
end
