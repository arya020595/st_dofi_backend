require "test_helper"

module Api
  module V1
    module Approvals
      # rubocop:disable Minitest/MultipleAssertions
      class FishermenControllerTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"

          admin_permissions = %w[list view approve].map do |action|
            Permission.find_or_create_by!(code: "fisherman_approvals.#{action}") do |permission|
              permission.name = "Fisherman approvals - #{action.capitalize}"
            end
          end
          @admin_role = create(:role, kind: Role::DOFI_OFFICER, permissions: admin_permissions)
          @no_access_role = create(:role)
          @fisherman_role = create(:role, :fisherman, name: "Fisherman")
          @jetty_manager_role = create(:role, kind: Role::JETTY_MANAGER, name: "Jetty Manager")

          @admin = create(:user, role: @admin_role, position: "Administrator", unit: "HQ",
                                 password: @password, password_confirmation: @password)
          @plain_user = create(:user, role: @no_access_role, password: @password, password_confirmation: @password)
          @fisherman = create(:user, role: @fisherman_role, status: "active", fisherman_status: "pending_approval",
                                     ic_number: "01-800001", registration_type: "Small - Scale (Full-Time)")

          @admin_headers = auth_headers_for(@admin, password: @password)
          @plain_headers = auth_headers_for(@plain_user, password: @password)
        end

        test "index requires the list/view permission" do
          get "/api/v1/admin/approvals/fishermen", headers: @plain_headers

          assert_response :forbidden

          get "/api/v1/admin/approvals/fishermen", headers: @admin_headers

          assert_response :ok
        end

        test "index excludes jetty manager role users" do
          jetty_manager = create(:user, role: @jetty_manager_role, status: "pending", ic_number: "01-800002",
                                        unit: "Docks", position: "Supervisor", contact_no: "71111111")

          get "/api/v1/admin/approvals/fishermen", headers: @admin_headers

          assert_response :ok
          ids = response.parsed_body["data"].pluck("id")

          assert_includes ids, @fisherman.id
          assert_not_includes ids, jetty_manager.id
        end

        test "show returns the merged owner and admin company profile" do
          company_profile = create(:company_profile, rocbn_no: "RC-SHARED")
          owner_contact = create(:company_profile_contact, company_profile: company_profile, ic_no: "01-800003",
                                                           designation: "Owner")
          admin_contact = create(:company_profile_contact, company_profile: company_profile, ic_no: "01-800004",
                                                           designation: "Admin")
          commercial_fisherman = create(:user, role: @fisherman_role, status: "active",
                                               fisherman_status: "pending_approval", ic_number: "01-800003",
                                               registration_type: "Commercial", designation: "Owner",
                                               company_profile: company_profile, company_profile_contact: owner_contact)

          get "/api/v1/admin/approvals/fishermen/#{commercial_fisherman.id}", headers: @admin_headers

          assert_response :ok
          data = response.parsed_body["data"]

          assert_company_profile_payload(data, company_profile)
          assert_contact_profiles_payload(data, owner_contact, admin_contact)
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
          remark = create(:approval_remark)

          post "/api/v1/admin/approvals/fishermen/#{@fisherman.id}/reject",
               params: { approval_remark_id: remark.id }, headers: @admin_headers

          assert_response :ok
          @fisherman.reload

          assert_equal "revoked", @fisherman.fisherman_status
          assert_equal remark.name, @fisherman.rejection_reason
        end

        test "reject with an invalid approval_remark_id fails" do
          post "/api/v1/admin/approvals/fishermen/#{@fisherman.id}/reject",
               params: { approval_remark_id: SecureRandom.uuid }, headers: @admin_headers

          assert_response :unprocessable_content
          assert_equal "pending_approval", @fisherman.reload.fisherman_status
        end

        test "a jetty manager id 404s against the fishermen approval endpoints" do
          jetty_manager = create(:user, role: @jetty_manager_role, status: "pending", ic_number: "01-800005",
                                        unit: "Docks", position: "Supervisor", contact_no: "71111111")

          get "/api/v1/admin/approvals/fishermen/#{jetty_manager.id}", headers: @admin_headers

          assert_response :not_found
        end

        private

        def assert_company_profile_payload(data, company_profile)
          assert_equal company_profile.id, data.dig("company_profile", "id")
          assert_equal company_profile.company_name, data.dig("company_profile", "company_name")
          assert_equal company_profile.rocbn_no, data.dig("company_profile", "rocbn_no")
        end

        def assert_contact_profiles_payload(data, owner_contact, admin_contact)
          assert_equal owner_contact.full_name, data.dig("owner_profile", "full_name")
          assert_equal admin_contact.full_name, data.dig("admin_profile", "full_name")
        end
      end
      # rubocop:enable Minitest/MultipleAssertions
    end
  end
end
