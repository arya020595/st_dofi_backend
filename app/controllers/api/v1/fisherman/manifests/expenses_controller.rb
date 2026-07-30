module Api
  module V1
    module Fisherman
      module Manifests
        class ExpensesController < ApplicationController
          include ::Manifests::ExpenseReadable

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

          def expense_params
            params.expect(expense: %i[fuel_litres fuel_bnd ice_litres ice_bnd ration_bnd])
          end
        end
      end
    end
  end
end
