require "test_helper"

module Api
  module V1
    module Manifests
      class CaptureReportsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"

          fisherman_permissions = %w[capture_reports.view capture_reports.list capture_reports.create
                                     capture_reports.update].map do |code|
            Permission.find_or_create_by!(code: code) { |p| p.name = code }
          end
          officer_permissions = %w[capture_report_verifications.view capture_report_verifications.list
                                   capture_report_verifications.verify
                                   capture_report_verifications.amendment].map do |code|
            Permission.find_or_create_by!(code: code) { |p| p.name = code }
          end

          @fisherman_role = create(:role, permissions: fisherman_permissions)
          @officer_role = create(:role, kind: Role::DOFI_OFFICER, name: "DoFi Officer",
                                        permissions: officer_permissions)

          @manifest = create(:manifest)
          @fisherman = create(:user, role: @fisherman_role, company_profile: @manifest.company_profile,
                                     password: @password, password_confirmation: @password)
          @officer = create(:user, role: @officer_role, position: "Administrator", unit: "HQ", username: "officer1",
                                   password: @password, password_confirmation: @password)

          @fisherman_headers = auth_headers_for(@fisherman, password: @password)
          @officer_headers = auth_headers_for(@officer, password: @password)
        end

        test "create adds a capture report to the manifest" do
          zone = create(:zone)
          params = { capture_report: { zone_id: zone.id, zone_area: "Zone 1A", longitude: 114.9, latitude: 4.9 } }

          assert_difference("CaptureReport.count", 1) do
            post "/api/v1/manifests/#{@manifest.id}/capture_reports", params: params,
                                                                      headers: @fisherman_headers, as: :json
          end

          assert_response :created
        end

        test "verify requires the verification permission, not the plain capture_reports permission" do
          report = create(:capture_report, manifest: @manifest)

          post "/api/v1/manifests/#{@manifest.id}/capture_reports/#{report.id}/verify", headers: @fisherman_headers

          assert_response :forbidden

          post "/api/v1/manifests/#{@manifest.id}/capture_reports/#{report.id}/verify", headers: @officer_headers

          assert_response :ok
          assert_equal "verified", report.reload.capture_report_status
        end

        test "request_amendment stores the remarks" do
          report = create(:capture_report, manifest: @manifest)

          post "/api/v1/manifests/#{@manifest.id}/capture_reports/#{report.id}/request_amendment",
               params: { remarks: "Fishing gear section invalid" }, headers: @officer_headers, as: :json

          assert_response :ok
          report.reload

          assert_equal "needs_amendment", report.capture_report_status
          assert_equal "Fishing gear section invalid", report.capture_report_remarks
        end
      end
    end
  end
end
