module Api
  module V1
    module Admin
      module EntityUsers
        class CompanyProfilesController < ApplicationController
          include RansackSearchable

          PROFILE_TYPES = User::VALID_REGISTRATION_TYPES.freeze

          before_action :set_company_profile, only: :users

          def index
            authorize CompanyProfile, policy_class: EntityUserPolicy
            return render_invalid_profile_type unless valid_profile_types?

            result = apply_ransack_search(filtered_company_profiles, default_sort: "updated_at desc")
            pagy, records = pagy(:offset, result)
            render json: { status: "success", data: EntityUserCompanyBlueprint.render_as_hash(records),
                           meta: pagination_meta(pagy) }
          end

          def users
            authorize @company_profile, policy_class: EntityUserPolicy
            result = apply_ransack_search(@company_profile.users.kept, default_sort: "created_at desc")
            pagy, records = pagy(:offset, result)
            render json: { status: "success", data: EntityUserBlueprint.render_as_hash(records),
                           meta: pagination_meta(pagy) }
          end

          private

          def set_company_profile
            @company_profile = company_profile_scope.find(params.expect(:id))
          end

          def company_profile_scope
            policy_scope(CompanyProfile, policy_scope_class: EntityUserPolicy::Scope)
          end

          def filtered_company_profiles
            profiles = company_profile_scope.select(company_profile_count_select)
            return profiles if profile_types.empty?

            profiles.where(registration_type: profile_types)
          end

          def profile_types
            @profile_types ||= [params[:registration_type], params[:registration_types]]
                               .flat_map { |value| Array(value).flat_map { |item| item.to_s.split(",") } }
                               .compact_blank
                               .uniq
          end

          def valid_profile_types? = profile_types.all? { |type| PROFILE_TYPES.include?(type) }

          def company_profile_count_select
            <<~SQL.squish
              company_profiles.*, (
                SELECT COUNT(*) FROM users
                WHERE users.company_profile_id = company_profiles.id AND users.discarded_at IS NULL
              ) AS entity_user_count
            SQL
          end

          def render_invalid_profile_type
            render json: { status: "fail", errors: ["Registration type is invalid"] }, status: :unprocessable_content
          end
        end
      end
    end
  end
end
