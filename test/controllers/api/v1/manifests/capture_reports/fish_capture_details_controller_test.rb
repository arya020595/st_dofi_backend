require "test_helper"

module Api
  module V1
    module Manifests
      module CaptureReports
        class FishCaptureDetailsControllerTest < ActionDispatch::IntegrationTest
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
            @dictionary = create(:dictionary, local_name: "Ikan Merah", scientific_name: "Lutjanus campechanus")

            @headers = auth_headers_for(@user, password: @password)
          end

          test "create snapshots the dictionary name and computes the overall total" do
            params = { fish_capture_detail: { dictionary_id: @dictionary.id, price_per_kg: 25.0,
                                              amount_captured_kg: 4.0 } }

            post "/api/v1/manifests/#{@manifest.id}/capture_reports/#{@report.id}/fish_capture_details",
                 params: params, headers: @headers, as: :json

            assert_response :created
            data = response.parsed_body["data"]

            assert_equal "Ikan Merah", data["local_name"]
            assert_equal "100.0", data["overall_total"]
          end

          test "bulk_sync upserts a new row by client id" do
            local_id = SecureRandom.uuid
            payload = { captures: [{ id: local_id, dictionary_id: @dictionary.id, price_per_kg: 10.0,
                                     amount_captured_kg: 2.0 }] }

            assert_difference("FishCaptureDetail.count", 1) do
              post "/api/v1/manifests/#{@manifest.id}/capture_reports/#{@report.id}/fish_capture_details/bulk_sync",
                   params: payload, headers: @headers, as: :json
            end

            assert_equal "success", response.parsed_body["data"].first["status"]
          end

          test "bulk_sync re-syncing the same client id is idempotent, not a duplicate" do
            local_id = SecureRandom.uuid
            payload = { captures: [{ id: local_id, dictionary_id: @dictionary.id, price_per_kg: 10.0,
                                     amount_captured_kg: 2.0 }] }
            post "/api/v1/manifests/#{@manifest.id}/capture_reports/#{@report.id}/fish_capture_details/bulk_sync",
                 params: payload, headers: @headers, as: :json

            assert_no_difference("FishCaptureDetail.count") do
              post "/api/v1/manifests/#{@manifest.id}/capture_reports/#{@report.id}/fish_capture_details/bulk_sync",
                   params: payload, headers: @headers, as: :json
            end
          end

          test "bulk_sync rejects a client id that already belongs to a different capture report" do
            local_id = SecureRandom.uuid
            payload = { captures: [{ id: local_id, dictionary_id: @dictionary.id, price_per_kg: 10.0,
                                     amount_captured_kg: 2.0 }] }
            post "/api/v1/manifests/#{@manifest.id}/capture_reports/#{@report.id}/fish_capture_details/bulk_sync",
                 params: payload, headers: @headers, as: :json
            other_report = create(:capture_report, manifest: @manifest)

            post "/api/v1/manifests/#{@manifest.id}/capture_reports/#{other_report.id}/fish_capture_details/bulk_sync",
                 params: payload, headers: @headers, as: :json

            assert_equal "fail", response.parsed_body["data"].first["status"]
          end
        end
      end
    end
  end
end
