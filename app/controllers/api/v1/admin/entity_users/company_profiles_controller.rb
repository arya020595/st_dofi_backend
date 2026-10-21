module Api
  module V1
    module Admin
      module EntityUsers
        class CompanyProfilesController < ApplicationController
          include RansackSearchable

          before_action :set_company_profile, only: :users

          def index
            authorize CompanyProfile, policy_class: EntityUserPolicy

            result = apply_ransack_search(company_profile_scope, default_sort: "updated_at desc")
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
        end
      end
    end
  end
end
