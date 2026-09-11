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

          test "index filters by profiling type and includes kept user count" do
            get "/api/v1/admin/entity_users/company_profiles",
                params: { registration_type: "Commercial,Small-Scale (Company)" }, headers: @headers

            assert_response :ok
            assert_equal @company_users.count, response.parsed_body.fetch("data").first.fetch("user_count")
          end

          test "users returns only the selected company profile users" do
            get "/api/v1/admin/entity_users/company_profiles/#{@commercial_profile.id}/users", headers: @headers

            assert_response :ok
            assert_equal @company_users.map(&:id).sort, response.parsed_body.fetch("data").pluck("id").sort
          end

          private

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
