module Api
  module V1
    module Manifests
      module CaptureReports
        class ExpensesController < ApplicationController
          before_action :set_capture_report

          def show
            authorize @capture_report, :show?

            expense = @capture_report.capture_report_expense
            if expense
              render json: { status: "success", data: CaptureReportExpenseBlueprint.render_as_hash(expense) }
            else
              render json: { status: "fail", errors: ["Expense not found"] }, status: :not_found
            end
          end

          def create
            authorize @capture_report, :update?
            upsert
          end

          def update
            authorize @capture_report, :update?
            upsert
          end

          private

          def upsert
            case CaptureReportExpenses::Upsert.call(@capture_report, expense_params)
            in Success(expense)
              render json: { status: "success", data: CaptureReportExpenseBlueprint.render_as_hash(expense) }
            in Failure(expense)
              render json: { status: "fail", errors: expense.errors.full_messages }, status: :unprocessable_content
            end
          end

          def set_capture_report
            manifest = policy_scope(::Manifest).find(params.expect(:manifest_id))
            @capture_report = manifest.capture_reports.find(params.expect(:capture_report_id))
          end

          def expense_params
            params.expect(expense: %i[fuel_litres fuel_bnd ice_litres ice_bnd ration_bnd])
          end
        end
      end
    end
  end
end
