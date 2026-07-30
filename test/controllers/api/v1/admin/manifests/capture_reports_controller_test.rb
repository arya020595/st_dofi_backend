require "test_helper"

module Api
  module V1
    module Admin
      module Manifests
        class CaptureReportsControllerTest < ActionDispatch::IntegrationTest
          setup do
            @manifest = create(:manifest)
          end

          test "verify with only the plain capture_reports permission is forbidden" do
            report = create(:capture_report, manifest: @manifest)
            headers = officer_headers_for(permission_codes: %w[capture_reports.view capture_reports.list])

            post "/api/v1/admin/manifests/#{@manifest.id}/capture_reports/#{report.id}/verify", headers: headers

            assert_response :forbidden
          end

          test "verify with the verification permission marks the report verified" do
            report = create(:capture_report, manifest: @manifest)
            headers = officer_headers_for(
              permission_codes: %w[capture_report_verifications.view capture_report_verifications.list
                                   capture_report_verifications.verify capture_report_verifications.amendment]
            )

            post "/api/v1/admin/manifests/#{@manifest.id}/capture_reports/#{report.id}/verify", headers: headers

            assert_response :ok
            assert_equal "verified", report.reload.capture_report_status
          end

          test "request_amendment stores the remarks" do
            report = create(:capture_report, manifest: @manifest)
            headers = officer_headers_for(
              permission_codes: %w[capture_report_verifications.view capture_report_verifications.list
                                   capture_report_verifications.verify capture_report_verifications.amendment]
            )

            post "/api/v1/admin/manifests/#{@manifest.id}/capture_reports/#{report.id}/request_amendment",
                 params: { remarks: "Fishing gear section invalid" }, headers: headers, as: :json

            assert_response :ok
            report.reload

            assert_equal "needs_amendment", report.capture_report_status
            assert_equal "Fishing gear section invalid", report.capture_report_remarks
          end

          test "index lists capture reports for the manifest" do
            create(:capture_report, manifest: @manifest)
            headers = officer_headers_for(permission_codes: %w[capture_reports.view capture_reports.list])

            get "/api/v1/admin/manifests/#{@manifest.id}/capture_reports", headers: headers

            assert_response :ok
            assert_equal 1, response.parsed_body["data"].size
          end
        end
      end
    end
  end
end
