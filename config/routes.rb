Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # devise_for is kept outside the api/v1 namespace so the routing "as:" scope doesn't rename the
  # mapping (and therefore current_user/authenticate_user!) to current_api_v1_user.
  devise_for :users,
             path: "api/v1/auth",
             controllers: { sessions: "api/v1/sessions" },
             skip: %i[registrations passwords confirmations unlocks]

  # devise_scope sets request.env["devise.mapping"], which DeviseController requires even for
  # custom, non-CRUD actions added to a Devise-derived controller (here, Sessions#me).
  devise_scope :user do
    get "api/v1/auth/me", to: "api/v1/sessions#me"
  end

  namespace :api do
    namespace :v1 do
      resources :users, only: %i[index show create update destroy]
      resources :roles, only: %i[index show create update destroy]
      resources :permissions, only: %i[index]
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
