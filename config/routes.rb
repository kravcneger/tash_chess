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
      resources :participations, only: %i[ create destroy ] do
        member do
          post :withdraw
          post :reinstate
        end
      end
      resources :rounds, only: %i[ show create destroy ], param: :number
      resource :standings, only: :show
      resource :screen, only: :show
    end
  end

  resources :games, only: :update

  resource :locale, only: :update

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
