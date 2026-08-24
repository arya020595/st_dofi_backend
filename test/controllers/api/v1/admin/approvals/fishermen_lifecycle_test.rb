require "test_helper"

module Api
  module V1
    module Approvals
      class FishermenLifecycleTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"
          @admin = create(:user, :officer_shaped, role: admin_role, password: @password,
                                                  password_confirmation: @password)
          @company_profile = create(:company_profile)
          @owner_role = create(:role, :fisherman, name: "Owner", company_profile: @company_profile,
                                                  is_default: true)
          @fisherman = create_fisherman("pending_approval")
          @headers = auth_headers_for(@admin, password: @password)
        end

        test "deactivate suspends an active fisherman" do
          activate_fisherman!

          post "/api/v1/admin/approvals/fishermen/#{@fisherman.id}/deactivate", headers: @headers

          assert_response :ok
          assert_equal "suspended", @fisherman.reload.fisherman_status
        end

        test "reactivate restores a suspended fisherman" do
          @fisherman.update!(fisherman_status: "suspended", claimed_at: Time.current,
                             brunei_id_verified_at: Time.current)

          post "/api/v1/admin/approvals/fishermen/#{@fisherman.id}/reactivate", headers: @headers

          assert_response :ok
          assert_equal "active", @fisherman.reload.fisherman_status
        end

        test "revoke claimable fisherman records revocation metadata" do
          @fisherman.update!(fisherman_status: "claimable")
          remark = create(:approval_remark, usage_scope: "revoke")

          post "/api/v1/admin/approvals/fishermen/#{@fisherman.id}/revoke",
               params: { approval_remark_id: remark.id, reason: "Access withdrawn" }, headers: @headers

          assert_response :ok
          @fisherman.reload

          assert_equal ["revoked", @admin.id, remark.id, "Access withdrawn"], revocation_payload
        end

        test "revoke pending approval fisherman is invalid and must use reject" do
          post "/api/v1/admin/approvals/fishermen/#{@fisherman.id}/revoke",
               params: { approval_remark_id: create(:approval_remark, usage_scope: "revoke").id },
               headers: @headers

          assert_response :unprocessable_content
          assert_equal "pending_approval", @fisherman.reload.fisherman_status
        end

        private

        def admin_role
          codes = %w[fisherman_approvals.deactivate fisherman_approvals.reactivate fisherman_approvals.revoke]
          create(:role, kind: Role::DOFI_OFFICER, permissions: find_or_create_permissions(codes))
        end

        def create_fisherman(status)
          create(:user, role: @owner_role, company_profile: @company_profile, status: "active",
                        fisherman_status: status, ic_number: "01-850001", registration_type: "Commercial",
                        provisioning_source: ::Fisherman::ProvisionUser::DOFI_COMPANY_PROFILE)
        end

        def activate_fisherman!
          @fisherman.update!(fisherman_status: "active", claimed_at: Time.current,
                             brunei_id_verified_at: Time.current)
        end

        def revocation_payload
          [@fisherman.fisherman_status, @fisherman.revoked_by_id, @fisherman.revocation_remark_id,
           @fisherman.revocation_comment]
        end
      end
    end
  end
end
