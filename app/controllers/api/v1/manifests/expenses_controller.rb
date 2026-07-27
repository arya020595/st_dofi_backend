module Api
  module V1
    module Manifests
      class ExpensesController < ApplicationController
        before_action :set_manifest

        def show
          authorize expense_record, :show?

          expense = @manifest.manifest_expense
          if expense
            render json: { status: "success", data: ManifestExpenseBlueprint.render_as_hash(expense) }
          else
            render json: { status: "fail", errors: ["Expense not found"] }, status: :not_found
          end
        end

        def create
          authorize expense_record, :create?
          upsert
        end

        def update
          authorize expense_record, :update?
          upsert
        end

        private

        def upsert
          case ManifestExpenses::Upsert.call(@manifest, expense_params)
          in Success(expense)
            render json: { status: "success", data: ManifestExpenseBlueprint.render_as_hash(expense) }
          in Failure(expense)
            render json: { status: "fail", errors: expense.errors.full_messages }, status: :unprocessable_content
          end
        end

        def set_manifest
          @manifest = policy_scope(::Manifest).find(params.expect(:manifest_id))
        end

        def expense_record
          @manifest.manifest_expense || ManifestExpense.new(manifest_id: @manifest.id)
        end

        def expense_params
          params.expect(expense: %i[fuel_litres fuel_bnd ice_litres ice_bnd ration_bnd])
        end
      end
    end
  end
end
