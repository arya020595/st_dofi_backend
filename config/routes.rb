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
      # No default REST actions (only: []) — profile only exposes self-service member actions
      # like :locale, scoped to current_user rather than an :id.
      resource :profile, only: [], controller: "profiles" do
        patch :locale
      end
      post "auth/brunei_id", to: "brunei_id_sessions#create"

      resources :users, only: %i[index show create update destroy]
      resources :company_profiles, only: %i[index show create update destroy] do
        resources :contacts, only: %i[create update destroy], module: "company_profiles"
        resources :vessels, module: "company_profiles" do
          member { post :images }
          resources :fishing_gears, module: "vessels"
        end
        resources :crews, module: "company_profiles"
        resources :captains, module: "company_profiles"
      end

      namespace :registrations do
        resource :jetty_manager, only: %i[create], controller: "jetty_managers"
        resource :fisherman, only: %i[create], controller: "fishermen"
        get "fisherman/company_profile", to: "company_profile_lookups#show"
        get "status", to: "status#show"
      end

      resources :roles, only: %i[index show create update destroy]
      resources :permissions, only: %i[index]
      resources :dictionaries, only: %i[index show create update destroy]

      namespace :fisherman do
        resources :manifests, only: %i[index show create destroy] do
          collection do
            get :tab_counts
          end
          member do
            post :submit_port_out
            post :resubmit_port_out
            post :submit_port_in
            post :resubmit_port_in
            post :skip_capture_report
            get :offline_bundle
          end
        end
      end

      # Nested manifest sub-resources are deliberately unprefixed (neither fisherman/ nor
      # approvals/) — capture_reports#verify/#request_amendment are officer actions invoked on a
      # resource the fisherman created, so nesting them under either audience's namespace would be
      # misleading. They're already authorized per-record by their own policies regardless of which
      # namespace listed/created the parent manifest.
      resources :manifests, only: [] do
        resources :minor_fishermen, module: "manifests"
        resources :capture_reports, module: "manifests" do
          member do
            post :verify
            post :request_amendment
            post :resubmit
          end
          resource :expense, only: %i[show create update], module: "capture_reports"
          resources :fish_capture_details, module: "capture_reports" do
            collection { post :bulk_sync }
          end
          resources :fishing_gear_details, module: "capture_reports"
        end
      end

      namespace :master_data do
        resources :ports, only: %i[index show create update destroy]
        resources :zones, only: %i[index show create update destroy]
        resources :fishing_gears, only: %i[index show create update destroy]
        resources :nationalities, only: %i[index show create update destroy]
        resources :positions, only: %i[index show create update destroy]
        resources :reasons, only: %i[index show create update destroy]
      end

      namespace :approvals do
        resources :fishermen, only: %i[index show] do
          member do
            post :approve
            post :reject
          end
        end

        resources :jetty_managers, only: %i[index show] do
          member do
            post :approve
            post :reject
          end
        end

        resources :approval_remarks, only: %i[index show create update destroy]

        resources :vessels, only: %i[index show] do
          member do
            post :approve
            post :request_amendment
          end
        end

        resources :crews, only: %i[index show] do
          member do
            post :approve
            post :request_amendment
          end
        end

        resources :captains, only: %i[index show] do
          member do
            post :approve
            post :request_amendment
          end
        end

        resources :fishing_gears, only: %i[index show] do
          member do
            post :approve
            post :request_amendment
          end
        end

        resources :manifests, only: %i[index show update] do
          collection do
            get :tab_counts
          end
          member do
            post :approve_port_out
            post :request_amendment_port_out
            post :approve_port_in
            post :request_amendment_port_in
          end
        end
      end
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
