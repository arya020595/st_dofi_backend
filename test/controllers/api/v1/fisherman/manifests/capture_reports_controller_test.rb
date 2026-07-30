require "test_helper"

module Api
  module V1
    module Fisherman
      module Manifests
        class CaptureReportsControllerTest < ActionDispatch::IntegrationTest
          setup do
            @manifest = create(:manifest)
            @headers = fisherman_headers_for(@manifest,
                                             permission_codes: %w[capture_reports.view capture_reports.list
                                                                  capture_reports.create capture_reports.update])
          end

          test "create adds a capture report to the manifest" do
            zone = create(:zone)
            params = { capture_report: { zone_id: zone.id, zone_area: "Zone 1A", longitude: 114.9, latitude: 4.9 } }

            assert_difference("CaptureReport.count", 1) do
              post "/api/v1/fisherman/manifests/#{@manifest.id}/capture_reports", params: params,
                                                                                  headers: @headers, as: :json
            end

            assert_response :created
          end

          test "update modifies the capture report" do
            report = create(:capture_report, manifest: @manifest)

            patch "/api/v1/fisherman/manifests/#{@manifest.id}/capture_reports/#{report.id}",
                  params: { capture_report: { zone_area: "Zone 2B" } }, headers: @headers, as: :json

            assert_response :ok
            assert_equal "Zone 2B", report.reload.zone_area
          end
        end
      end
    end
  end
end
