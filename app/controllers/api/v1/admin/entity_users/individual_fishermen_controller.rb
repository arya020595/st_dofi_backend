module Api
  module V1
    module Admin
      module EntityUsers
        class IndividualFishermenController < ApplicationController
          include RansackSearchable

          def index
            authorize User, policy_class: EntityUserPolicy

            result = apply_ransack_search(individual_fishermen, default_sort: "created_at desc")
            pagy, records = pagy(:offset, result)
            render json: { status: "success", data: EntityUserIndividualFishermanBlueprint.render_as_hash(records),
                           meta: pagination_meta(pagy) }
          end

          private

          def individual_fishermen
            ::EntityUsers::IndividualFishermenQuery.call(
              scope: policy_scope(User, policy_scope_class: EntityUserPolicy::Scope),
              registration_types: CompanyProfile::INDIVIDUAL_REGISTRATION_TYPES
            )
          end
        end
      end
    end
  end
end
