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
      post "auth/brunei_id/callback", to: "brunei_id_sessions#callback"

      namespace :registrations do
        resource :jetty_manager, only: %i[create], controller: "jetty_managers"
        resource :fisherman, only: %i[create], controller: "fishermen"
        post "fisherman/company_profile_lookup", to: "company_profile_lookups#create"
        get "status", to: "status#show"
      end

      resources :permissions, only: %i[index]

      # Generic Active Storage redirect endpoint (see docs/minio/MINIO.md §3-4): authorizes against the
      # attachment's owning record, then 302s to a freshly-signed MinIO URL. Works for any
      # attachable model with a Pundit policy — not Dictionary-specific.
      get "attachments/:signed_id", to: "attachments#show", as: :attachment

      # profile/locale, permissions, and attachments above are deliberately outside both admin/ and
      # fisherman/ — none of them has any audience-specific behavior (no Pundit differentiation at
      # all for the first two; attachments delegates entirely to whichever record owns the blob), so
      # namespacing them would be noise, not signal. Everything else below sits inside admin/ or
      # fisherman/, each tagged `defaults: { audience: "admin"/"fisherman" }` for RequireAudience
      # (app/controllers/concerns/require_audience.rb) — a coarse pre-filter in front of Pundit's
      # own per-action/per-record checks, not a replacement for them.

      # ==================== admin/ : DoFi Officer + Jetty Manager ====================
      namespace :admin, defaults: { audience: "admin" } do
        resources :users, only: %i[index show create update destroy]
        resources :roles, only: %i[index show create update destroy]
        resources :dictionaries, only: %i[index show create update destroy]

        namespace :master_data do
          resources :ports, only: %i[index show create update destroy], controller: "/api/v1/admin/ports"
          resources :zones, only: %i[index show create update destroy], controller: "/api/v1/admin/zones"
          resources :fishing_gears,
                    only: %i[index show create update destroy],
                    controller: "/api/v1/admin/fishing_gears"
          resources :reasons, only: %i[index show create update destroy]
          resources :nationalities, only: %i[index show create update destroy]
          resources :positions, only: %i[index show create update destroy]
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

          resources :fishing_gears, only: %i[index show] do
            member do
              post :approve
              post :request_amendment
            end
          end

          resources :documents, only: %i[index show] do
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
              get :port_out_approval
              get :port_in_approval
              post :approve_port_out
              post :request_amendment_port_out
              post :approve_port_in
              post :request_amendment_port_in
            end
          end
        end

        # Dual-mounted, not moved — same controllers as fisherman/company_profiles below; each
        # resource's own Policy::Scope (CompaniesVesselPolicy::Scope etc.) decides what's visible.
        resources :company_profiles, only: %i[index show create update destroy],
                                     controller: "/api/v1/company_profiles" do
          resources :contacts, only: %i[create update destroy], controller: "/api/v1/company_profiles/contacts"
          resources :vessels, controller: "/api/v1/company_profiles/vessels" do
            member { post :images }
            resources :fishing_gears, controller: "/api/v1/company_profiles/vessels/fishing_gears"
          end
          resources :crews, controller: "/api/v1/company_profiles/crews"
          resources :documents, only: %i[index create update], controller: "/api/v1/company_profiles/documents"
        end

        # Admin only reviews these manifest sub-resources (index/show + the officer-only capture
        # report workflow actions) — fisherman owns creating/editing them, see fisherman/manifests
        # below. Native Admin::Manifests::* controllers, sharing read-only logic with their
        # Fisherman:: counterparts via the Manifests:: concerns (app/controllers/concerns/manifests).
        # `scope module:` (not just nested `resources`) is required to route to the nested
        # Admin::Manifests::/Admin::Manifests::CaptureReports:: controller modules — nested
        # `resources` blocks alone only affect the URL/params, not the controller's module path.
        resources :manifests, only: [] do
          scope module: "manifests" do
            resources :minor_fishermen, only: %i[index]
            resource :expense, only: %i[show]
            resources :capture_reports, only: %i[index show] do
              member do
                post :verify
                post :request_amendment
              end
              scope module: "capture_reports" do
                resources :fish_capture_details, only: %i[index show]
                resources :fishing_gear_details, only: %i[index show]
              end
            end
          end
        end
      end

      # ==================== fisherman/ : Fisherman PWA ====================
      namespace :fisherman, defaults: { audience: "fisherman" } do
        # A company's own self-management of its users/roles — company-scoped mirror of
        # admin/users and admin/roles above. See Fisherman::UsersController/RolesController,
        # UserPolicy/RolePolicy, and Role::PLATFORM_SCOPES.
        resources :users, only: %i[index show create update destroy]
        resources :roles, only: %i[index show create update destroy]

        namespace :dashboard do
          get :summary, to: "/api/v1/fisherman/dashboard#summary"
          get :top_fishes, to: "/api/v1/fisherman/dashboard#top_fishes"
          get :fishing_gear_analytics, to: "/api/v1/fisherman/dashboard#fishing_gear_analytics"
          get :zone_analytics, to: "/api/v1/fisherman/dashboard#zone_analytics"
        end

        resources :manifests, only: %i[index show create update destroy] do
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

          # Fisherman owns these manifest sub-resources (create/update/delete + resubmit); DoFi
          # Officer's read/verify-only access lives in the parallel nested block under admin/
          # manifests above. Native Fisherman::Manifests::* controllers, sharing read-only logic
          # with Admin:: via the Manifests:: concerns (app/controllers/concerns/manifests).
          # `scope module:` (see the matching admin/ comment above) routes to the nested
          # Fisherman::Manifests::/Fisherman::Manifests::CaptureReports:: controller modules.
          scope module: "manifests" do
            resources :minor_fishermen, only: %i[index create destroy]
            resource :expense, only: %i[show create update]
            resources :capture_reports, only: %i[index show create update] do
              member do
                post :resubmit
              end
              scope module: "capture_reports" do
                resources :fish_capture_details, only: %i[index show create update destroy] do
                  collection { post :bulk_sync }
                end
                resources :fishing_gear_details, only: %i[index show create update destroy]
              end
            end
          end
        end

        namespace :master_data do
          resources :ports, only: %i[index show], controller: "/api/v1/fisherman/ports"
          resources :zones, only: %i[index show], controller: "/api/v1/fisherman/zones"
          resources :fishing_gears, only: %i[index show], controller: "/api/v1/fisherman/fishing_gears"
          resources :positions, only: %i[index show], controller: "/api/v1/fisherman/positions"
        end
        resources :vessels, only: %i[index]
        resources :captains, only: %i[index]
        resources :crews, only: %i[index]
        resources :dictionaries, only: %i[index]
        resources :company_profiles, only: %i[index show create update destroy],
                                     controller: "/api/v1/company_profiles" do
          resources :contacts, only: %i[create update destroy], controller: "/api/v1/company_profiles/contacts"
          resources :vessels, controller: "/api/v1/company_profiles/vessels" do
            member { post :images }
            resources :fishing_gears, controller: "/api/v1/company_profiles/vessels/fishing_gears"
          end
          resources :crews, controller: "/api/v1/company_profiles/crews"
          resources :documents, only: %i[index create update], controller: "/api/v1/company_profiles/documents"
        end
      end
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
