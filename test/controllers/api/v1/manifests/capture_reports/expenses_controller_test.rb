require "test_helper"

module Api
  module V1
    module Manifests
      module CaptureReports
        class ExpensesControllerTest < ActionDispatch::IntegrationTest
          setup do
            @password = "Password123!"

            permissions = %w[capture_reports.view capture_reports.update].map do |code|
              Permission.find_or_create_by!(code: code) { |p| p.name = code }
            end
            @role = create(:role, permissions: permissions)
            @manifest = create(:manifest)
            @user = create(:user, role: @role, company_profile: @manifest.company_profile,
                                  password: @password, password_confirmation: @password)
            @report = create(:capture_report, manifest: @manifest)

            @headers = auth_headers_for(@user, password: @password)
          end

          test "create upserts the expense record" do
            params = { expense: { fuel_litres: 120.0, fuel_bnd: 180.0, ice_litres: 80.0, ice_bnd: 24.0,
                                  ration_bnd: 35.0 } }

            post "/api/v1/manifests/#{@manifest.id}/capture_reports/#{@report.id}/expense",
                 params: params, headers: @headers, as: :json

            assert_response :ok
            assert_equal 1, @report.reload.capture_report_expense.present? ? 1 : 0
          end

          test "update modifies the existing expense without creating a duplicate" do
            create(:capture_report_expense, capture_report: @report, fuel_litres: 50.0)

            assert_no_difference("CaptureReportExpense.count") do
              patch "/api/v1/manifests/#{@manifest.id}/capture_reports/#{@report.id}/expense",
                    params: { expense: { fuel_litres: 200.0 } }, headers: @headers, as: :json
            end

            assert_response :ok
            assert_in_delta(200.0, @report.reload.capture_report_expense.fuel_litres)
          end

          test "show returns not_found when no expense exists yet" do
            get "/api/v1/manifests/#{@manifest.id}/capture_reports/#{@report.id}/expense", headers: @headers

            assert_response :not_found
          end
        end
      end
    end
  end
end
