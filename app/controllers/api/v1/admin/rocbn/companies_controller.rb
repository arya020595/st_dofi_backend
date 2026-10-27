module Api
  module V1
    module Admin
      module Rocbn
        # Read-only lookup of the external ROCBN company registry for Add Profiling: search by company name or ROCBN
        # number (index), then fetch the chosen company to autofill the form (show). Never writes to either database.
        # This namespace shadows ::Rocbn, so the model is always written ::Rocbn::Company.
        class CompaniesController < ApplicationController
          include RansackSearchable

          # The only predicates that count as a search: a registry-wide filter such as company_name_present would
          # otherwise satisfy "has a criterion" while still matching every row.
          SEARCH_PREDICATES = %w[cont eq].freeze

          rescue_from(*::Rocbn::BaseRecord::UNAVAILABLE_ERRORS, with: :render_registry_unavailable)

          before_action :set_company, only: :show

          def index
            authorize ::Rocbn::Company, policy_class: RocbnCompanyPolicy
            result = apply_ransack_search(registry_scope.for_listing)
            unless search_criteria?
              return render_error(I18n.t("errors.rocbn_search_criteria_required"), :unprocessable_content)
            end

            pagy, records = pagy(:offset, result)
            render json: { status: "success", data: RocbnCompanyBlueprint.render_as_hash(records),
                           meta: pagination_meta(pagy) }
          end

          def show
            authorize @company, policy_class: RocbnCompanyPolicy
            render json: { status: "success", data: RocbnCompanyDetailBlueprint.render_as_hash(@company) }
          end

          private

          def set_company
            @company = registry_scope.find(params.expect(:id))
          end

          def registry_scope
            policy_scope(::Rocbn::Company, policy_scope_class: RocbnCompanyPolicy::Scope)
          end

          # Ransack drops blank values and unknown fields, so a request with nothing usable has no conditions.
          def search_criteria?
            @q.base.conditions.any? { |condition| SEARCH_PREDICATES.include?(condition.predicate.name) }
          end

          def render_registry_unavailable(exception)
            Rails.error.report(exception, handled: true)
            render_error(I18n.t("errors.rocbn_unavailable"), :service_unavailable)
          end
        end
      end
    end
  end
end
