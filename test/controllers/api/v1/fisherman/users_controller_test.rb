require "test_helper"

module Api
  module V1
    module Fisherman
      module UsersControllerTestSetup
        def setup
          super

          @password = "Password123!"
          create_roles
          create_users
          create_headers
        end

        def create_roles
          @company_profile = create(:company_profile)
          @owner_role = create(:role, :fisherman, company_profile: @company_profile, name: "Owner",
                                                  is_default: true, permissions: owner_permissions)
          @admin_role = create(:role, :fisherman, company_profile: @company_profile, name: "Admin",
                                                  is_default_admin: true)
          @member_role = create(:role, :fisherman, company_profile: @company_profile)
          @no_access_role = create(:role, :fisherman, company_profile: @company_profile)
        end

        def owner_permissions
          %w[list view create update delete].map do |action|
            Permission.find_or_create_by!(code: "fisherman_users.#{action}") do |permission|
              permission.name = "Fisherman users - #{action.capitalize}"
              permission.platform_scope = Permission::FISHERMAN_PLATFORM
            end
          end
        end

        def create_users
          @owner = create_active_fisherman(@owner_role)
          @plain_user = create_password_fisherman(@no_access_role)
          @target = create(:user, role: @member_role, company_profile: @company_profile,
                                  ic_number: SecureRandom.hex(5), registration_type: "Commercial")
        end

        def create_headers
          @owner_headers = auth_headers_for(@owner, password: @password)
          @plain_headers = auth_headers_for(@plain_user, password: @password)
        end

        def create_active_fisherman(role)
          timestamp = Time.current
          create_password_fisherman(role, fisherman_status: "active", claimed_at: timestamp,
                                          brunei_id_verified_at: timestamp)
        end

        def create_password_fisherman(role, extra_attributes = {})
          create(:user, { role: role, company_profile: @company_profile, ic_number: SecureRandom.hex(5),
                          registration_type: "Commercial", password: @password,
                          password_confirmation: @password }.merge(extra_attributes))
        end
      end

      class UsersControllerTest < ActionDispatch::IntegrationTest
        include UsersControllerTestSetup

        test "index requires the list/view permission" do
          get "/api/v1/fisherman/users", headers: @plain_headers

          assert_response :forbidden

          get "/api/v1/fisherman/users", headers: @owner_headers

          assert_response :ok
        end

        test "index only returns users from this company" do
          other_company_user = create(:user, role: create(:role, :fisherman), ic_number: SecureRandom.hex(5),
                                             registration_type: "Commercial")

          get "/api/v1/fisherman/users", headers: @owner_headers

          assert_response :ok
          ids = response.parsed_body["data"].pluck("id")

          assert_includes ids, @target.id
          assert_not_includes ids, other_company_user.id
        end

        test "show 404s for a user from another company" do
          other_company_user = create(:user, role: create(:role, :fisherman), ic_number: SecureRandom.hex(5),
                                             registration_type: "Commercial")

          get "/api/v1/fisherman/users/#{other_company_user.id}", headers: @owner_headers

          assert_response :not_found
        end

        test "create persists a teammate in this company, ignoring any client-supplied company_profile" do
          foreign_company = create(:company_profile)

          assert_difference("User.count", 1) do
            post "/api/v1/fisherman/users", params: { user: { name: "New Teammate",
                                                              ic_number: SecureRandom.hex(5),
                                                              registration_type: "Commercial",
                                                              role_id: @member_role.id,
                                                              company_profile_id: foreign_company.id } },
                                            headers: @owner_headers, as: :json
          end

          assert_response :created
          assert_equal @company_profile, User.last.company_profile
        end

        test "create rejects a role_id belonging to another company" do
          foreign_role = create(:role, :fisherman)

          assert_no_difference("User.count") do
            post "/api/v1/fisherman/users", params: { user: { name: "Blocked", ic_number: SecureRandom.hex(5),
                                                              registration_type: "Commercial",
                                                              role_id: foreign_role.id } },
                                            headers: @owner_headers, as: :json
          end

          assert_response :unprocessable_content
          assert_includes response.parsed_body["errors"].join, "is not a role available to you"
        end

        test "create rejects a dofi_officer role_id" do
          officer_role = create(:role, kind: Role::DOFI_OFFICER)

          post "/api/v1/fisherman/users", params: { user: { name: "Blocked", ic_number: SecureRandom.hex(5),
                                                            registration_type: "Commercial",
                                                            role_id: officer_role.id } },
                                          headers: @owner_headers, as: :json

          assert_response :unprocessable_content
          assert_includes response.parsed_body["errors"].join, "is not a role available to you"
        end

        test "update 404s for a user from another company" do
          other_company_user = create(:user, role: create(:role, :fisherman), ic_number: SecureRandom.hex(5),
                                             registration_type: "Commercial")

          patch "/api/v1/fisherman/users/#{other_company_user.id}", params: { user: { name: "Hijacked" } },
                                                                    headers: @owner_headers, as: :json

          assert_response :not_found
        end

        test "update reassigns this company's own user to Admin role" do
          patch "/api/v1/fisherman/users/#{@target.id}", params: { user: { role_id: @admin_role.id } },
                                                         headers: @owner_headers, as: :json

          assert_response :ok
          assert_equal @admin_role.id, @target.reload.role_id
        end

        test "update rejects reassigning to another company's role" do
          foreign_role = create(:role, :fisherman)

          patch "/api/v1/fisherman/users/#{@target.id}", params: { user: { role_id: foreign_role.id } },
                                                         headers: @owner_headers, as: :json

          assert_response :unprocessable_content
          assert_includes response.parsed_body["errors"].join, "is not a role available to you"
        end

        # Distinct from the scope-layer test above: this proves the permission-check layer in
        # isolation. @plain_user's role carries no fisherman_users.* permissions at all, so the
        # attempt is rejected by UserPolicy#update? before Users::Update's own role-scope validation
        # (proven separately above with an *authorized* actor) is ever reached.
        test "update rejects a self-reassignment attempt without fisherman_users.update permission" do
          patch "/api/v1/fisherman/users/#{@plain_user.id}", params: { user: { role_id: @owner_role.id } },
                                                             headers: @plain_headers, as: :json

          assert_response :forbidden
          assert_equal @no_access_role.id, @plain_user.reload.role_id
        end

        test "destroy soft-deletes a user from this company" do
          delete "/api/v1/fisherman/users/#{@target.id}", headers: @owner_headers

          assert_response :ok
          assert_predicate @target.reload, :discarded?
        end

        test "destroy 404s for a user from another company" do
          other_company_user = create(:user, role: create(:role, :fisherman), ic_number: SecureRandom.hex(5),
                                             registration_type: "Commercial")

          delete "/api/v1/fisherman/users/#{other_company_user.id}", headers: @owner_headers

          assert_response :not_found
        end
      end
    end
  end
end
