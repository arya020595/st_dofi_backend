require "test_helper"

module Api
  module V1
    module Approvals
      class FishermenControllerTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"

          admin_permissions = %w[list view approve].map do |action|
            Permission.find_or_create_by!(code: "fisherman_approvals.#{action}") do |permission|
              permission.name = "Fisherman approvals - #{action.capitalize}"
            end
          end
          @admin_role = create(:role, permissions: admin_permissions)
          @no_access_role = create(:role)
          @fisherman_role = create(:role, kind: Role::FISHERMAN, name: "Fisherman")
          @jetty_manager_role = create(:role, kind: Role::JETTY_MANAGER, name: "Jetty Manager")

          @admin = create(:user, role: @admin_role, password: @password, password_confirmation: @password)
          @plain_user = create(:user, role: @no_access_role, password: @password, password_confirmation: @password)
          @fisherman = create(:user, role: @fisherman_role, status: "pending", ic_number: "01-800001",
                                     registration_type: "Small - Scale (Full-Time)")

          @admin_headers = auth_headers_for(@admin, password: @password)
          @plain_headers = auth_headers_for(@plain_user, password: @password)
        end

        test "index requires the list/view permission" do
          get "/api/v1/approvals/fishermen", headers: @plain_headers

          assert_response :forbidden

          get "/api/v1/approvals/fishermen", headers: @admin_headers

          assert_response :ok
        end

        test "index excludes jetty manager role users" do
          jetty_manager = create(:user, role: @jetty_manager_role, status: "pending", ic_number: "01-800002",
                                        unit: "Docks", position: "Supervisor", contact_no: "71111111")

          get "/api/v1/approvals/fishermen", headers: @admin_headers

          assert_response :ok
          ids = response.parsed_body["data"].pluck("id")

          assert_includes ids, @fisherman.id
          assert_not_includes ids, jetty_manager.id
        end

        test "show returns the merged owner and admin company profile" do
          owner_profile = create(:company_profile, ic_no: "01-800003", rocbn_no: "RC-SHARED", designation: "Owner")
          admin_profile = create(:company_profile, ic_no: "01-800004", rocbn_no: "RC-SHARED", designation: "Admin",
                                                   company_name: owner_profile.company_name)
          commercial_fisherman = create(:user, role: @fisherman_role, status: "pending", ic_number: "01-800003",
                                               registration_type: "Commercial", designation: "Owner",
                                               company_profile: owner_profile)

          get "/api/v1/approvals/fishermen/#{commercial_fisherman.id}", headers: @admin_headers

          assert_response :ok
          data = response.parsed_body["data"]

          assert_equal owner_profile.full_name, data.dig("owner_profile", "full_name")
          assert_equal admin_profile.full_name, data.dig("admin_profile", "full_name")
        end

        test "approve transitions the fisherman from pending to active" do
          post "/api/v1/approvals/fishermen/#{@fisherman.id}/approve", headers: @admin_headers

          assert_response :ok
          assert_equal "active", @fisherman.reload.status
        end

        test "approve without permission is forbidden" do
          post "/api/v1/approvals/fishermen/#{@fisherman.id}/approve", headers: @plain_headers

          assert_response :forbidden
        end

        test "reject requires an approval_remark_id and persists its name as the rejection reason" do
          remark = create(:approval_remark)

          post "/api/v1/approvals/fishermen/#{@fisherman.id}/reject",
               params: { approval_remark_id: remark.id }, headers: @admin_headers

          assert_response :ok
          @fisherman.reload

          assert_equal "rejected", @fisherman.status
          assert_equal remark.name, @fisherman.rejection_reason
        end

        test "reject with an invalid approval_remark_id fails" do
          post "/api/v1/approvals/fishermen/#{@fisherman.id}/reject",
               params: { approval_remark_id: SecureRandom.uuid }, headers: @admin_headers

          assert_response :unprocessable_content
          assert_equal "pending", @fisherman.reload.status
        end

        test "a jetty manager id 404s against the fishermen approval endpoints" do
          jetty_manager = create(:user, role: @jetty_manager_role, status: "pending", ic_number: "01-800005",
                                        unit: "Docks", position: "Supervisor", contact_no: "71111111")

          get "/api/v1/approvals/fishermen/#{jetty_manager.id}", headers: @admin_headers

          assert_response :not_found
        end
      end
    end
  end
end
