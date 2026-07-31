require "test_helper"

module Api
  module V1
    module Admin
      module Manifests
        module CaptureReports
          class FishingGearDetailsControllerTest < ActionDispatch::IntegrationTest
            setup do
              @manifest = create(:manifest)
              @report = create(:capture_report, manifest: @manifest)
              @headers = officer_headers_for(permission_codes: %w[capture_reports.view capture_reports.list])
            end

            test "index lists fishing gear details for the capture report" do
              create(:fishing_gear_detail, capture_report: @report)

              get "/api/v1/admin/manifests/#{@manifest.id}/capture_reports/#{@report.id}/fishing_gear_details",
                  headers: @headers

              assert_response :ok
              assert_equal 1, response.parsed_body["data"].size
            end
          end
        end
      end
    end
  end
end
