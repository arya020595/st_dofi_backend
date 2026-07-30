require "test_helper"

module Api
  module V1
    module Approvals
      class JettyManagersControllerTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"

          admin_permissions = %w[list view approve].map do |action|
            Permission.find_or_create_by!(code: "jetty_manager_approvals.#{action}") do |permission|
              permission.name = "Jetty manager approvals - #{action.capitalize}"
            end
          end
          @admin_role = create(:role, kind: Role::DOFI_OFFICER, permissions: admin_permissions)
          @no_access_role = create(:role)
          @fisherman_role = create(:role, kind: Role::FISHERMAN, name: "Fisherman")
          @jetty_manager_role = create(:role, kind: Role::JETTY_MANAGER, name: "Jetty Manager")

          @admin = create(:user, role: @admin_role, position: "Administrator", unit: "HQ",
                                 password: @password, password_confirmation: @password)
          @plain_user = create(:user, role: @no_access_role, password: @password, password_confirmation: @password)
          @jetty_manager = create(:user, role: @jetty_manager_role, status: "pending", ic_number: "01-810001",
                                         unit: "Docks", position: "Supervisor", contact_no: "71111111")

          @admin_headers = auth_headers_for(@admin, password: @password)
          @plain_headers = auth_headers_for(@plain_user, password: @password)
        end

        test "index requires the list/view permission" do
          get "/api/v1/admin/approvals/jetty_managers", headers: @plain_headers

          assert_response :forbidden

          get "/api/v1/admin/approvals/jetty_managers", headers: @admin_headers

          assert_response :ok
        end

        test "index excludes fisherman role users" do
          fisherman = create(:user, role: @fisherman_role, status: "pending", ic_number: "01-810002",
                                    registration_type: "Small - Scale (Full-Time)")

          get "/api/v1/admin/approvals/jetty_managers", headers: @admin_headers

          assert_response :ok
          ids = response.parsed_body["data"].pluck("id")

          assert_includes ids, @jetty_manager.id
          assert_not_includes ids, fisherman.id
        end

        test "approve transitions the jetty manager from pending to active" do
          post "/api/v1/admin/approvals/jetty_managers/#{@jetty_manager.id}/approve", headers: @admin_headers

          assert_response :ok
          assert_equal "active", @jetty_manager.reload.status
        end

        test "approve without permission is forbidden" do
          post "/api/v1/admin/approvals/jetty_managers/#{@jetty_manager.id}/approve", headers: @plain_headers

          assert_response :forbidden
        end

        test "reject requires an approval_remark_id and persists its name as the rejection reason" do
          remark = create(:approval_remark)

          post "/api/v1/admin/approvals/jetty_managers/#{@jetty_manager.id}/reject",
               params: { approval_remark_id: remark.id }, headers: @admin_headers

          assert_response :ok
          @jetty_manager.reload

          assert_equal "rejected", @jetty_manager.status
          assert_equal remark.name, @jetty_manager.rejection_reason
        end

        test "a fisherman id 404s against the jetty manager approval endpoints" do
          fisherman = create(:user, role: @fisherman_role, status: "pending", ic_number: "01-810003",
                                    registration_type: "Small - Scale (Full-Time)")

          get "/api/v1/admin/approvals/jetty_managers/#{fisherman.id}", headers: @admin_headers

          assert_response :not_found
        end
      end
    end
  end
end
