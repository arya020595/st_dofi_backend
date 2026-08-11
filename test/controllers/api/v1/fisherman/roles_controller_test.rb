require "test_helper"

module Api
  module V1
    module Fisherman
      class RolesControllerTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"

          @view_permission = Permission.find_or_create_by!(code: "manifest_list.view") do |permission|
            permission.name = "Manifest list - View"
            permission.platform_scope = Permission::SHARED_PLATFORM
          end
          role_permissions = %w[list view create update delete].map do |action|
            Permission.find_or_create_by!(code: "fisherman_roles.#{action}") do |permission|
              permission.name = "Fisherman roles - #{action.capitalize}"
              permission.platform_scope = Permission::FISHERMAN_PLATFORM
            end
          end

          @company_profile = create(:company_profile)
          @owner_role = create(:role, :fisherman, company_profile: @company_profile, is_default: true,
                                                  permissions: role_permissions)
          @no_access_role = create(:role, :fisherman, company_profile: @company_profile)
          @target = create(:role, :fisherman, company_profile: @company_profile, permissions: [@view_permission])

          @owner = create(:user, role: @owner_role, company_profile: @company_profile, ic_number: SecureRandom.hex(5),
                                 registration_type: "Commercial", password: @password,
                                 password_confirmation: @password)
          @plain_user = create(:user, role: @no_access_role, company_profile: @company_profile,
                                      ic_number: SecureRandom.hex(5), registration_type: "Commercial",
                                      password: @password, password_confirmation: @password)

          @owner_headers = auth_headers_for(@owner, password: @password)
          @plain_headers = auth_headers_for(@plain_user, password: @password)
        end

        test "index requires the list/view permission" do
          get "/api/v1/fisherman/roles", headers: @plain_headers

          assert_response :forbidden

          get "/api/v1/fisherman/roles", headers: @owner_headers

          assert_response :ok
        end

        test "index only returns this company's fisherman roles, never dofi_officer or another company's" do
          other_company_role = create(:role, :fisherman)
          admin_role = create(:role, kind: Role::DOFI_OFFICER)

          get "/api/v1/fisherman/roles", headers: @owner_headers

          assert_response :ok
          ids = response.parsed_body["data"].pluck("id")

          assert_equal [@target.id], ids & [@target.id, other_company_role.id, admin_role.id]
        end

        test "show 404s for another company's role" do
          other_company_role = create(:role, :fisherman)

          get "/api/v1/fisherman/roles/#{other_company_role.id}", headers: @owner_headers

          assert_response :not_found
        end

        test "create persists a role scoped to this company, ignoring any client-supplied platform/company" do
          foreign_company = create(:company_profile)

          post "/api/v1/fisherman/roles",
               params: { role: { name: "Crew Manager", platform_scope: "dofi_officer",
                                 company_profile_id: foreign_company.id },
                         permission_codes: [@view_permission.code] },
               headers: @owner_headers, as: :json

          assert_response :created
          data = response.parsed_body["data"]

          assert_equal ["fisherman", @company_profile.id], data.values_at("platform_scope", "company_profile_id")
          assert_includes data["permissions"].pluck("code"), @view_permission.code
        end

        test "create rejects a permission code belonging to the dofi_officer platform" do
          officer_only = create(:permission, code: "roles.create", platform_scope: Permission::DOFI_OFFICER_PLATFORM)

          assert_no_difference("Role.count") do
            post "/api/v1/fisherman/roles", params: { role: { name: "Sneaky Role" },
                                                      permission_codes: [officer_only.code] },
                                            headers: @owner_headers, as: :json
          end

          assert_response :unprocessable_content
          assert_includes response.parsed_body["errors"].join, "not available to the fisherman platform"
        end

        test "update 404s for another company's role" do
          other_company_role = create(:role, :fisherman)

          patch "/api/v1/fisherman/roles/#{other_company_role.id}", params: { role: { name: "Hijacked" } },
                                                                    headers: @owner_headers, as: :json

          assert_response :not_found
        end

        test "update replaces the permission set for this company's own role" do
          another_permission = create(:permission)

          patch "/api/v1/fisherman/roles/#{@target.id}", params: { role: { name: "Renamed" },
                                                                   permission_codes: [another_permission.code] },
                                                         headers: @owner_headers, as: :json

          assert_response :ok
          codes = response.parsed_body.dig("data", "permissions").pluck("code")

          assert_equal [another_permission.code], codes
        end

        test "destroy removes a non-default role" do
          delete "/api/v1/fisherman/roles/#{@target.id}", headers: @owner_headers

          assert_response :ok
        end

        test "destroy refuses the company's default Owner role" do
          delete "/api/v1/fisherman/roles/#{@owner_role.id}", headers: @owner_headers

          assert_response :forbidden
        end

        test "destroy 404s for another company's role" do
          other_company_role = create(:role, :fisherman)

          delete "/api/v1/fisherman/roles/#{other_company_role.id}", headers: @owner_headers

          assert_response :not_found
        end
      end
    end
  end
end
