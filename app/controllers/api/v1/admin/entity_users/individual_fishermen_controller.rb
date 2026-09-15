module Api
  module V1
    module Admin
      module EntityUsers
        class IndividualFishermenController < ApplicationController
          include RansackSearchable

          def index
            authorize User, policy_class: EntityUserPolicy
            return render_invalid_profile_type unless valid_profile_types?

            result = apply_ransack_search(individual_fishermen, default_sort: "created_at desc")
            pagy, records = pagy(:offset, result)
            render json: { status: "success", data: EntityUserIndividualFishermanBlueprint.render_as_hash(records),
                           meta: pagination_meta(pagy) }
          end

          private

          def individual_fishermen
            ::EntityUsers::IndividualFishermenQuery.call(
              scope: policy_scope(User, policy_scope_class: EntityUserPolicy::Scope),
              registration_types: profile_types
            )
          end

          def profile_types
            @profile_types ||= requested_profile_types.presence || CompanyProfile::INDIVIDUAL_REGISTRATION_TYPES
          end

          def requested_profile_types
            [params[:registration_type], params[:registration_types]]
              .flat_map { |value| Array(value).flat_map { |item| item.to_s.split(",") } }
              .compact_blank
              .uniq
          end

          def valid_profile_types?
            profile_types.all? { |type| CompanyProfile::INDIVIDUAL_REGISTRATION_TYPES.include?(type) }
          end

          def render_invalid_profile_type
            render json: { status: "fail", errors: ["Registration type must be Full-Time or Part-Time"] },
                   status: :unprocessable_content
          end
        end
      end
    end
  end
end
