require "test_helper"

module Api
  module V1
    module Approvals
      class FishingGearsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"

          admin_permissions = %w[view list approve amendment].map do |action|
            Permission.find_or_create_by!(code: "companies_fishing_gear_approvals.#{action}") do |p|
              p.name = "Approvals - #{action}"
            end
          end
          @admin_role = create(:role, permissions: admin_permissions)
          @no_access_role = create(:role)

          @admin = create(:user, role: @admin_role, password: @password, password_confirmation: @password)
          @plain_user = create(:user, role: @no_access_role, password: @password, password_confirmation: @password)
          @gear = create(:companies_fishing_gear)

          @admin_headers = auth_headers_for(@admin, password: @password)
          @plain_headers = auth_headers_for(@plain_user, password: @password)
        end

        test "index requires the list/view permission" do
          get "/api/v1/approvals/fishing_gears", headers: @plain_headers

          assert_response :forbidden

          get "/api/v1/approvals/fishing_gears", headers: @admin_headers

          assert_response :ok
        end

        test "approve transitions the company fishing gear from pending to approved" do
          post "/api/v1/approvals/fishing_gears/#{@gear.id}/approve", headers: @admin_headers

          assert_response :ok
          assert_equal "approved", @gear.reload.approval_status
        end

        test "request_amendment records the remarks and moves the gear to amendment_required" do
          post "/api/v1/approvals/fishing_gears/#{@gear.id}/request_amendment",
               params: { remarks: "Quantity looks wrong" }, headers: @admin_headers, as: :json

          assert_response :ok
          assert_equal "amendment_required", @gear.reload.approval_status
        end
      end
    end
  end
end
