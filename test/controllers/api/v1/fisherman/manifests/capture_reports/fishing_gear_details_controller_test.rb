require "test_helper"

module Api
  module V1
    module Fisherman
      module Manifests
        module CaptureReports
          class FishingGearDetailsControllerTest < ActionDispatch::IntegrationTest
            setup do
              @manifest = create(:manifest)
              @report = create(:capture_report, manifest: @manifest)
              @company_gear = create(:companies_fishing_gear, :approved,
                                     company_profile: @manifest.company_profile,
                                     companies_vessel: @manifest.companies_vessel)
              @headers = fisherman_headers_for(@manifest,
                                               permission_codes: %w[capture_reports.view capture_reports.create
                                                                    capture_reports.update])
            end

            test "create snapshots the master fishing gear's name, type, and specification" do
              params = { fishing_gear_detail: { companies_fishing_gear_id: @company_gear.id, quantity: 2 } }

              post "/api/v1/fisherman/manifests/#{@manifest.id}/capture_reports/#{@report.id}/fishing_gear_details",
                   params: params, headers: @headers, as: :json

              assert_response :created
              data = response.parsed_body["data"]

              assert_equal @company_gear.fishing_gear.name, data["name"]
              assert_equal @company_gear.fishing_gear.gear_type, data["gear_type"]
            end

            test "destroy removes the gear detail" do
              detail = create(:fishing_gear_detail, capture_report: @report)

              delete "/api/v1/fisherman/manifests/#{@manifest.id}/capture_reports/#{@report.id}" \
                     "/fishing_gear_details/#{detail.id}", headers: @headers

              assert_response :ok
              assert_not FishingGearDetail.exists?(detail.id)
            end

            test "create rejects a gear assigned to a different vessel" do
              another_vessel = create(:companies_vessel, :approved, company_profile: @manifest.company_profile)
              another_gear = create(:companies_fishing_gear, :approved,
                                    company_profile: @manifest.company_profile,
                                    companies_vessel: another_vessel)
              params = { fishing_gear_detail: { companies_fishing_gear_id: another_gear.id, quantity: 2 } }

              post "/api/v1/fisherman/manifests/#{@manifest.id}/capture_reports/#{@report.id}/fishing_gear_details",
                   params: params, headers: @headers, as: :json

              assert_response :unprocessable_content
              error = "Companies fishing gear must reference an approved fishing gear assigned to this manifest's " \
                      "vessel"

              assert_includes response.parsed_body["errors"], error
            end
          end
        end
      end
    end
  end
end
