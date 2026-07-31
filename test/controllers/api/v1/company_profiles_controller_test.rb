require "test_helper"

module Api
  module V1
    class CompanyProfilesControllerTest < ActionDispatch::IntegrationTest
      setup do
        @password = "Password123!"

        admin_permissions = %w[list view create update delete].map do |action|
          Permission.find_or_create_by!(code: "profiling.#{action}") do |permission|
            permission.name = "Profiling - #{action.capitalize}"
          end
        end
        @admin_role = create(:role, kind: Role::DOFI_OFFICER, permissions: admin_permissions)
        @no_access_role = create(:role, kind: Role::JETTY_MANAGER)

        @admin = create(:user, :officer_shaped, role: @admin_role,
                                                password: @password, password_confirmation: @password)
        @plain_user = create(:user, :jetty_manager_shaped, role: @no_access_role,
                                                           password: @password, password_confirmation: @password)
        @target = create(:company_profile)

        @admin_headers = auth_headers_for(@admin, password: @password)
        @plain_headers = auth_headers_for(@plain_user, password: @password)
      end

      def valid_params(overrides = {})
        {
          company_profile: {
            registration_type: "Small-Scale (Company)", company_name: "New Profiling Co",
            company_address: "Spg 1, Test", rocbn_no: "RC-NEW-001", contact_no: "71222222",
            district: "Brunei - Muara", mukim: "Serasa", village: "Kapok",
            fisherman_card_no: "R-2026-000999", issue_date: "2026-01-01", license_expiry_date: "2026-12-31",
            worker_quota: 10,
            owner: { full_name: "Owner Person", gender: "Male", ic_no: "01-700010", ic_colour: "Yellow" }
          }.merge(overrides)
        }
      end

      test "index requires the list/view permission" do
        get "/api/v1/admin/company_profiles", headers: @plain_headers

        assert_response :forbidden

        get "/api/v1/admin/company_profiles", headers: @admin_headers

        assert_response :ok
      end

      test "index filters by company_name via ransack" do
        create(:company_profile, company_name: "Findable Fish Co", rocbn_no: "RC-FINDABLE")

        get "/api/v1/admin/company_profiles", params: { q: { company_name_cont: "Findable" } }, headers: @admin_headers

        assert_response :ok
        assert_equal ["Findable Fish Co"], response.parsed_body["data"].pluck("company_name")
      end

      test "index returns one entry per company, nesting the admin profile under the owner" do
        company_profile = create(:company_profile, company_name: "Two Person Co", rocbn_no: "RC-TWO-PERSON")
        create(:company_profile_contact, company_profile: company_profile, designation: "Owner")
        create(:company_profile_contact, company_profile: company_profile, designation: "Admin",
                                         full_name: "Admin Person")

        get "/api/v1/admin/company_profiles", params: { q: { rocbn_no_eq: "RC-TWO-PERSON" } }, headers: @admin_headers

        assert_response :ok
        data = response.parsed_body["data"]

        assert_equal [company_profile.id], data.pluck("id")
        assert_equal "Admin Person", data.first.dig("admin_profile", "full_name")
      end

      test "index omits the admin profile when the company has no admin" do
        company_profile = create(:company_profile, company_name: "Solo Co", rocbn_no: "RC-SOLO")
        create(:company_profile_contact, company_profile: company_profile, designation: "Owner")

        get "/api/v1/admin/company_profiles", params: { q: { rocbn_no_eq: "RC-SOLO" } }, headers: @admin_headers

        assert_response :ok
        assert_nil response.parsed_body["data"].first["admin_profile"]
      end

      test "create with only an owner persists one company profile and one contact" do
        assert_difference({ "CompanyProfile.count" => 1, "CompanyProfileContact.count" => 1 }) do
          post "/api/v1/admin/company_profiles", params: valid_params, headers: @admin_headers, as: :json
        end

        data = response.parsed_body["data"]

        assert_equal "Owner Person", data.dig("owner_profile", "full_name")
        assert_nil data["admin_profile"]
      end

      test "create with both owner and admin persists one company profile and two contacts" do
        params = valid_params(admin: { full_name: "Admin Person", gender: "Female", ic_no: "01-700011",
                                       ic_colour: "Green" })

        assert_difference({ "CompanyProfile.count" => 1, "CompanyProfileContact.count" => 2 }) do
          post "/api/v1/admin/company_profiles", params: params, headers: @admin_headers, as: :json
        end

        data = response.parsed_body["data"]

        assert_equal "Admin Person", data.dig("admin_profile", "full_name")
        assert_equal data.dig("company_profile", "id"), data.dig("owner_profile", "company_profile_id")
      end

      test "create without permission is forbidden" do
        post "/api/v1/admin/company_profiles", params: valid_params, headers: @plain_headers, as: :json

        assert_response :forbidden
      end

      test "create with a missing required field rolls back and returns errors" do
        assert_no_difference(["CompanyProfile.count", "CompanyProfileContact.count"]) do
          post "/api/v1/admin/company_profiles", params: valid_params(company_name: ""), headers: @admin_headers,
                                                 as: :json
        end

        assert_response :unprocessable_content
        assert_predicate response.parsed_body["errors"], :present?
      end

      test "update modifies the target profile" do
        patch "/api/v1/admin/company_profiles/#{@target.id}", params: { company_profile: { worker_quota: 99 } },
                                                              headers: @admin_headers, as: :json

        assert_response :ok
        assert_equal 99, @target.reload.worker_quota
      end

      test "destroy soft-deletes the target profile and its kept contacts" do
        contact = create(:company_profile_contact, company_profile: @target, designation: "Owner")

        delete "/api/v1/admin/company_profiles/#{@target.id}", headers: @admin_headers

        assert_response :ok
        assert_predicate @target.reload, :discarded?
        assert_predicate contact.reload, :discarded?
      end
    end
  end
end
