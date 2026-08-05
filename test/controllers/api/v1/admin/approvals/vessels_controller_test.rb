require "test_helper"

module Api
  module V1
    module Approvals
      class VesselsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"

          admin_permissions = %w[view list approve amendment].map do |action|
            Permission.find_or_create_by!(code: "companies_vessel_approvals.#{action}") do |p|
              p.name = "Approvals - #{action}"
            end
          end
          @admin_role = create(:role, kind: Role::DOFI_OFFICER, permissions: admin_permissions)
          @no_access_role = create(:role)

          @admin = create(:user, role: @admin_role, position: "Administrator", unit: "HQ",
                                 password: @password, password_confirmation: @password)
          @plain_user = create(:user, role: @no_access_role, password: @password, password_confirmation: @password)
          @vessel = create(:companies_vessel)

          @admin_headers = auth_headers_for(@admin, password: @password)
          @plain_headers = auth_headers_for(@plain_user, password: @password)
        end

        test "index requires the list/view permission" do
          get "/api/v1/admin/approvals/vessels", headers: @plain_headers

          assert_response :forbidden

          get "/api/v1/admin/approvals/vessels", headers: @admin_headers

          assert_response :ok
        end

        test "approve transitions the vessel from pending to approved" do
          post "/api/v1/admin/approvals/vessels/#{@vessel.id}/approve", headers: @admin_headers

          assert_response :ok
          assert_equal "approved", @vessel.reload.approval_status
        end

        test "approve also approves the vessel's fishing gears" do
          pending_gear = create(:companies_fishing_gear,
                                company_profile: @vessel.company_profile,
                                companies_vessel: @vessel)
          amended_gear = create(:companies_fishing_gear,
                                company_profile: @vessel.company_profile,
                                companies_vessel: @vessel)
          amended_gear.request_amendment!(remarks: "Fix quantity")

          post "/api/v1/admin/approvals/vessels/#{@vessel.id}/approve", headers: @admin_headers

          assert_response :ok
          assert_equal "approved", pending_gear.reload.approval_status
          assert_equal "approved", amended_gear.reload.approval_status
        end

        test "approve without permission is forbidden" do
          post "/api/v1/admin/approvals/vessels/#{@vessel.id}/approve", headers: @plain_headers

          assert_response :forbidden
        end

        test "request_amendment records the remarks and moves the vessel to amendment_required" do
          post "/api/v1/admin/approvals/vessels/#{@vessel.id}/request_amendment",
               params: { remarks: "Boat number mismatch" }, headers: @admin_headers, as: :json

          assert_response :ok
          @vessel.reload

          assert_equal "amendment_required", @vessel.approval_status
          assert_equal "Boat number mismatch", @vessel.amendment_remarks
        end
      end
    end
  end
end
