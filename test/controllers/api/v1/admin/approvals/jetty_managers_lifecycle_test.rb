require "test_helper"

module Api
  module V1
    module Approvals
      class JettyManagersLifecycleTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"
          @admin = create(:user, :officer_shaped, role: admin_role, password: @password,
                                                  password_confirmation: @password)
          @jetty_role = create(:role, kind: Role::JETTY_MANAGER, name: "Jetty Manager")
          @jetty_manager = create(:user, :jetty_manager_shaped, role: @jetty_role, status: "active")
          @headers = auth_headers_for(@admin, password: @password)
        end

        test "deactivate inactivates an active jetty manager" do
          post "/api/v1/admin/approvals/jetty_managers/#{@jetty_manager.id}/deactivate", headers: @headers

          assert_response :ok
          assert_equal "inactive", @jetty_manager.reload.status
        end

        test "reactivate restores an inactive jetty manager" do
          @jetty_manager.update!(status: "inactive")

          post "/api/v1/admin/approvals/jetty_managers/#{@jetty_manager.id}/reactivate", headers: @headers

          assert_response :ok
          assert_equal "active", @jetty_manager.reload.status
        end

        test "revoke inactivates and records revocation metadata" do
          remark = create(:approval_remark, usage_scope: "revoke")

          post "/api/v1/admin/approvals/jetty_managers/#{@jetty_manager.id}/revoke",
               params: { approval_remark_id: remark.id, reason: "No longer authorized" }, headers: @headers

          assert_response :ok
          @jetty_manager.reload

          assert_equal ["inactive", @admin.id, remark.id, "No longer authorized"], revocation_payload
        end

        test "reactivate is blocked for revoked jetty manager" do
          @jetty_manager.update!(status: "inactive", revoked_at: Time.current, revoked_by: @admin)

          post "/api/v1/admin/approvals/jetty_managers/#{@jetty_manager.id}/reactivate", headers: @headers

          assert_response :unprocessable_content
          assert_equal "inactive", @jetty_manager.reload.status
        end

        test "reject permission is independent from approve permission" do
          actor = create(:user, :officer_shaped, role: approve_only_role, password: @password,
                                                 password_confirmation: @password)

          post "/api/v1/admin/approvals/jetty_managers/#{@jetty_manager.id}/reject",
               params: { approval_remark_id: create(:approval_remark, usage_scope: "reject").id },
               headers: auth_headers_for(actor, password: @password)

          assert_response :forbidden
        end

        private

        def admin_role
          codes = %w[
            jetty_manager_approvals.deactivate jetty_manager_approvals.reactivate jetty_manager_approvals.revoke
          ]
          create(:role, kind: Role::DOFI_OFFICER, permissions: find_or_create_permissions(codes))
        end

        def approve_only_role
          create(:role, name: "Approve Only",
                        permissions: find_or_create_permissions(%w[jetty_manager_approvals.approve]))
        end

        def revocation_payload
          [@jetty_manager.status, @jetty_manager.revoked_by_id, @jetty_manager.revocation_remark_id,
           @jetty_manager.revocation_comment]
        end
      end
    end
  end
end
