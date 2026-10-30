require "test_helper"

module Api
  module V1
    module Admin
      module EntityUsers
        class CompanyProfilesControllerTest < ActionDispatch::IntegrationTest
          setup do
            @password = "Password123!"
            @officer = create_officer
            @headers = auth_headers_for(@officer, password: @password)
            @commercial_profile = create(:company_profile, registration_type: "Commercial")
            @individual_profile = create(:company_profile, registration_type: "Small - Scale (Full-Time)")
            @company_users = create_company_users(@commercial_profile)
          end

          test "index filters by registration type via ransack and includes kept user count" do
            get "/api/v1/admin/entity_users/company_profiles",
                params: { q: { registration_type_in: ["Commercial"] } }, headers: @headers

            assert_response :ok
            data = response.parsed_body.fetch("data")

            assert_equal [@commercial_profile.id], data.pluck("id")
            assert_equal @company_users.count, data.first.fetch("user_count")
          end

          test "users returns only the selected company profile users" do
            get "/api/v1/admin/entity_users/company_profiles/#{@commercial_profile.id}/users", headers: @headers

            assert_response :ok
            assert_equal @company_users.map(&:id).sort, response.parsed_body.fetch("data").pluck("id").sort
          end

          # The tester's report: a company switches a claimed teammate to inactive on Assigned Users, yet this screen
          # kept showing it as active because it read the claim lifecycle and never the company's own switch.
          test "users shows a teammate as inactive once the company switched them off on Assigned Users" do
            crew = @company_users.last
            crew.update!(fisherman_status: "active", claimed_at: Time.current, brunei_id_verified_at: Time.current)
            manager_headers = auth_headers_for(create_user_manager, password: @password)

            patch "/api/v1/fisherman/users/#{crew.id}", params: { user: { status: "inactive" } },
                                                        headers: manager_headers, as: :json

            assert_response :ok
            get "/api/v1/admin/entity_users/company_profiles/#{@commercial_profile.id}/users", headers: @headers

            assert_equal "inactive", response.parsed_body.fetch("data").find { |user| user["id"] == crew.id }["status"]
          end

          private

          def create_user_manager
            permission = Permission.find_or_create_by!(code: "fisherman_users.update") do |record|
              record.name = record.code
              record.platform_scope = Permission::FISHERMAN_PLATFORM
            end
            role = create(:role, :fisherman, company_profile: @commercial_profile, name: "Manager",
                                             permissions: [permission])
            create(:user, role:, company_profile: @commercial_profile, ic_number: "01-811003",
                          registration_type: "Commercial", password: @password, password_confirmation: @password)
          end

          def create_officer
            permission = Permission.find_or_create_by!(code: "entity_users.list") do |record|
              record.name = record.code
            end
            role = create(:role, kind: Role::DOFI_OFFICER, permissions: [permission])
            create(:user, role:, position: "Administrator", unit: "HQ", password: @password,
                          password_confirmation: @password)
          end

          def create_company_users(company_profile)
            owner_role = create(:role, :fisherman, company_profile:, name: "Owner", is_default: true)
            crew_role = create(:role, :fisherman, company_profile:, name: "Crew")
            [
              create(:user, role: owner_role, company_profile:, ic_number: "01-811001",
                            registration_type: "Commercial"),
              create(:user, role: crew_role, company_profile:, ic_number: "01-811002", registration_type: "Commercial")
            ]
          end
        end
      end
    end
  end
end
