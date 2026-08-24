require "test_helper"

module Api
  module V1
    module Approvals
      # rubocop:disable Minitest/MultipleAssertions
      class FishermenControllerTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"

          admin_permissions = %w[list view approve reject deactivate reactivate revoke].map do |action|
            Permission.find_or_create_by!(code: "fisherman_approvals.#{action}") do |permission|
              permission.name = "Fisherman approvals - #{action.capitalize}"
            end
          end
          @admin_role = create(:role, kind: Role::DOFI_OFFICER, permissions: admin_permissions)
          @no_access_role = create(:role)
          @company_profile = create(:company_profile)
          @fisherman_role = create(:role, :fisherman, name: "Owner", company_profile: @company_profile,
                                                      is_default: true)
          @custom_fisherman_role = create(:role, :fisherman, name: "Crew", company_profile: @company_profile)
          @jetty_manager_role = create(:role, kind: Role::JETTY_MANAGER, name: "Jetty Manager")

          @admin = create(:user, role: @admin_role, position: "Administrator", unit: "HQ",
                                 password: @password, password_confirmation: @password)
          @plain_user = create(:user, role: @no_access_role, password: @password, password_confirmation: @password)
          @fisherman = create(:user, role: @fisherman_role, status: "active", fisherman_status: "pending_approval",
                                     provisioning_source: Fisherman::ProvisionUser::DOFI_COMPANY_PROFILE,
                                     company_profile: @company_profile, ic_number: "01-800001",
                                     registration_type: "Small - Scale (Full-Time)")

          @admin_headers = auth_headers_for(@admin, password: @password)
          @plain_headers = auth_headers_for(@plain_user, password: @password)
        end

        test "index requires the list/view permission" do
          get "/api/v1/admin/approvals/fishermen", headers: @plain_headers

          assert_response :forbidden

          get "/api/v1/admin/approvals/fishermen", headers: @admin_headers

          assert_response :ok
        end

        test "approve transitions the fisherman from pending approval to claimable" do
          post "/api/v1/admin/approvals/fishermen/#{@fisherman.id}/approve", headers: @admin_headers

          assert_response :ok
          @fisherman.reload

          assert_equal "claimable", @fisherman.fisherman_status
          assert_predicate @fisherman, :approved_at?
          assert_equal @admin.id, @fisherman.approved_by_id
        end

        test "approve without permission is forbidden" do
          post "/api/v1/admin/approvals/fishermen/#{@fisherman.id}/approve", headers: @plain_headers

          assert_response :forbidden
        end

        test "reject requires an approval_remark_id and persists its name as the rejection reason" do
          remark = create(:approval_remark, usage_scope: "reject")

          post "/api/v1/admin/approvals/fishermen/#{@fisherman.id}/reject",
               params: { approval_remark_id: remark.id }, headers: @admin_headers

          assert_response :ok
          @fisherman.reload

          assert_equal "revoked", @fisherman.fisherman_status
          assert_equal remark.name, @fisherman.rejection_reason
          assert_nil @fisherman.revoked_at
        end

        test "reject with an invalid approval_remark_id fails" do
          post "/api/v1/admin/approvals/fishermen/#{@fisherman.id}/reject",
               params: { approval_remark_id: SecureRandom.uuid }, headers: @admin_headers

          assert_response :unprocessable_content
          assert_equal "pending_approval", @fisherman.reload.fisherman_status
        end
      end
      # rubocop:enable Minitest/MultipleAssertions
    end
  end
end
