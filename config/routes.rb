Rails.application.routes.draw do
  root "tournaments#index"

  resources :players

  resources :tournaments do
    member do
      post :start
      post :finish
      post :reset
    end

    scope module: :tournaments do
      resources :participations, only: %i[ show create destroy ] do
        member do
          post :withdraw
          post :reinstate
        end
      end
      resources :rounds, only: %i[ show create destroy ], param: :number
      resource :standings, only: :show
      resource :countdown, only: %i[ create destroy ]
      resource :screen, only: :show
    end
  end

  resources :games, only: :update

  # Members on their phones, without the arbiter's login: the QR code of their participation signs them in to that
  # tournament, where they follow the standings and enter the result of their game.
  get "join/:token", to: "play/sessions#create", as: :join
  scope "play/:tournament_id", module: :play, as: :play do
    get "/", to: "tournaments#show", as: :tournament
    resources :games, only: :update
    resource :session, only: :destroy
  end

  resource :locale, only: :update

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
