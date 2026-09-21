module Api
  module V1
    module Admin
      module Manifests
        class ExpensesController < ApplicationController
          before_action :set_manifest

          def show
            authorize @manifest, policy_class: ManifestApprovalPolicy

            expense = @manifest.manifest_expense
            if expense
              render json: { status: "success", data: ManifestExpenseBlueprint.render_as_hash(expense) }
            else
              render json: { status: "fail", errors: ["Expense not found"] }, status: :not_found
            end
          end

          private

          def set_manifest
            @manifest = policy_scope(Manifest, policy_scope_class: ManifestApprovalPolicy::Scope)
                        .find(params.expect(:manifest_id))
          end
        end
      end
    end
  end
end
