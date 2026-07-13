require "test_helper"

module Api
  module V1
    module CompanyProfiles
      class ContactsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"

          admin_permissions = %w[list view create update delete].map do |action|
            Permission.find_or_create_by!(code: "profiling.#{action}") do |permission|
              permission.name = "Profiling - #{action.capitalize}"
            end
          end
          @admin_role = create(:role, permissions: admin_permissions)
          @no_access_role = create(:role)

          @admin = create(:user, role: @admin_role, password: @password, password_confirmation: @password)
          @plain_user = create(:user, role: @no_access_role, password: @password, password_confirmation: @password)
          @company_profile = create(:company_profile)
          @owner = create(:company_profile_contact, company_profile: @company_profile, designation: "Owner")

          @admin_headers = auth_headers_for(@admin, password: @password)
          @plain_headers = auth_headers_for(@plain_user, password: @password)
        end

        test "create adds an Admin contact to an existing company without touching the Owner" do
          params = { contact: { full_name: "Admin Person", gender: "Female", ic_no: "01-800001",
                                ic_colour: "Green", designation: "Admin" } }

          assert_difference("CompanyProfileContact.count", 1) do
            post "/api/v1/company_profiles/#{@company_profile.id}/contacts", params: params,
                                                                             headers: @admin_headers, as: :json
          end

          assert_response :created
          assert_equal "Admin Person", response.parsed_body.dig("data", "full_name")
        end

        test "create without permission is forbidden" do
          params = { contact: { full_name: "Admin Person", gender: "Female", ic_no: "01-800002",
                                ic_colour: "Green", designation: "Admin" } }

          post "/api/v1/company_profiles/#{@company_profile.id}/contacts", params: params,
                                                                           headers: @plain_headers, as: :json

          assert_response :forbidden
        end

        test "editing the company's details does not desync the Owner/Admin pairing" do
          admin = create(:company_profile_contact, company_profile: @company_profile, designation: "Admin")

          patch "/api/v1/company_profiles/#{@company_profile.id}",
                params: { company_profile: { company_name: "Renamed Co", rocbn_no: "RC-RENAMED" } },
                headers: @admin_headers, as: :json

          assert_response :ok

          get "/api/v1/company_profiles/#{@company_profile.id}", headers: @admin_headers
          data = response.parsed_body["data"]

          assert_equal admin.id, data.dig("admin_profile", "id")
        end

        test "update modifies the target contact" do
          patch "/api/v1/company_profiles/#{@company_profile.id}/contacts/#{@owner.id}",
                params: { contact: { full_name: "Updated Name" } }, headers: @admin_headers, as: :json

          assert_response :ok
          assert_equal "Updated Name", @owner.reload.full_name
        end

        test "destroy soft-deletes only the target contact, leaving the company profile intact" do
          delete "/api/v1/company_profiles/#{@company_profile.id}/contacts/#{@owner.id}", headers: @admin_headers

          assert_response :ok
          assert_predicate @owner.reload, :discarded?
          assert_not @company_profile.reload.discarded?
        end
      end
    end
  end
end
