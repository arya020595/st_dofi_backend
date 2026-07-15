require "test_helper"

module Api
  module V1
    module Manifests
      module CaptureReports
        class FishingGearDetailsControllerTest < ActionDispatch::IntegrationTest
          setup do
            @password = "Password123!"

            permissions = %w[capture_reports.view capture_reports.create capture_reports.update].map do |code|
              Permission.find_or_create_by!(code: code) { |p| p.name = code }
            end
            @role = create(:role, permissions: permissions)
            @manifest = create(:manifest)
            @user = create(:user, role: @role, company_profile: @manifest.company_profile,
                                  password: @password, password_confirmation: @password)
            @report = create(:capture_report, manifest: @manifest)
            @company_gear = create(:companies_fishing_gear, :approved, company_profile: @manifest.company_profile)

            @headers = auth_headers_for(@user, password: @password)
          end

          test "create snapshots the master fishing gear's name, type, and specification" do
            params = { fishing_gear_detail: { companies_fishing_gear_id: @company_gear.id, quantity: 2 } }

            post "/api/v1/manifests/#{@manifest.id}/capture_reports/#{@report.id}/fishing_gear_details",
                 params: params, headers: @headers, as: :json

            assert_response :created
            data = response.parsed_body["data"]

            assert_equal @company_gear.fishing_gear.name, data["name"]
            assert_equal @company_gear.fishing_gear.gear_type, data["gear_type"]
          end

          test "destroy removes the gear detail" do
            detail = create(:fishing_gear_detail, capture_report: @report)

            delete "/api/v1/manifests/#{@manifest.id}/capture_reports/#{@report.id}/fishing_gear_details/#{detail.id}",
                   headers: @headers

            assert_response :ok
            assert_not FishingGearDetail.exists?(detail.id)
          end
        end
      end
    end
  end
end
