require "test_helper"

module Api
  module V1
    module Approvals
      class FishermenScopeTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"
          @company_profile = create(:company_profile)
          @owner_role = create(:role, :fisherman, name: "Owner", company_profile: @company_profile,
                                                  is_default: true)
          @custom_role = create(:role, :fisherman, name: "Crew", company_profile: @company_profile)
          @jetty_role = create(:role, kind: Role::JETTY_MANAGER, name: "Jetty Manager")
          @admin = create(:user, :officer_shaped, role: admin_role, password: @password,
                                                  password_confirmation: @password)
          @headers = auth_headers_for(@admin, password: @password)
        end

        test "index includes only Company Profiling Owner/Admin fishermen" do
          governed = create_fisherman(@owner_role, "pending_approval", "01-830001",
                                      ::Fisherman::ProvisionUser::DOFI_COMPANY_PROFILE)
          custom = create_fisherman(@custom_role, "claimable", "01-830002",
                                    ::Fisherman::ProvisionUser::FISHERMAN_OWNER)
          jetty = create(:user, :jetty_manager_shaped, role: @jetty_role, status: "pending")

          get "/api/v1/admin/approvals/fishermen", headers: @headers

          assert_response :ok
          assert_equal [true, false, false], inclusion_flags(governed, custom, jetty)
        end

        test "direct custom fisherman id is forbidden for FINS actions" do
          custom = create_fisherman(@custom_role, "claimable", "01-830003",
                                    ::Fisherman::ProvisionUser::FISHERMAN_OWNER)

          post "/api/v1/admin/approvals/fishermen/#{custom.id}/revoke",
               params: { approval_remark_id: create(:approval_remark, usage_scope: "revoke").id },
               headers: @headers

          assert_response :forbidden
          assert_equal "claimable", custom.reload.fisherman_status
        end

        test "jetty manager id is not found against fisherman approval endpoints" do
          jetty = create(:user, :jetty_manager_shaped, role: @jetty_role, status: "pending")

          get "/api/v1/admin/approvals/fishermen/#{jetty.id}", headers: @headers

          assert_response :not_found
        end

        private

        def admin_role
          codes = [
            "fisherman_approvals.list",
            "fisherman_approvals.view",
            "fisherman_approvals.revoke"
          ]
          permissions = find_or_create_permissions(codes)
          create(:role, kind: Role::DOFI_OFFICER, permissions: permissions)
        end

        def create_fisherman(role, status, ic_number, source)
          create(:user, role: role, company_profile: @company_profile, status: "active",
                        fisherman_status: status, ic_number: ic_number, registration_type: "Commercial",
                        provisioning_source: source)
        end

        def inclusion_flags(*users)
          ids = response.parsed_body["data"].pluck("id")
          users.map { |user| ids.include?(user.id) }
        end
      end
    end
  end
end
