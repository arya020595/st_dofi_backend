require "test_helper"

module Api
  module V1
    module CompanyProfiles
      class CrewsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"

          admin_permissions = %w[view list create update delete].map do |action|
            Permission.find_or_create_by!(code: "companies_crews.#{action}") { |p| p.name = "Crews - #{action}" }
          end
          @admin_role = create(:role, kind: Role::DOFI_OFFICER, permissions: admin_permissions)
          @no_access_role = create(:role, kind: Role::JETTY_MANAGER)

          @admin = create(:user, :officer_shaped, role: @admin_role,
                                                  password: @password, password_confirmation: @password)
          @company_profile = create(:company_profile)
          @plain_user = create(:user, :jetty_manager_shaped, role: @no_access_role, company_profile: @company_profile,
                                                             password: @password, password_confirmation: @password)

          @admin_headers = auth_headers_for(@admin, password: @password)
          @plain_headers = auth_headers_for(@plain_user, password: @password)
        end

        test "index requires the list/view permission" do
          get "/api/v1/admin/company_profiles/#{@company_profile.id}/crews", headers: @plain_headers

          assert_response :forbidden

          get "/api/v1/admin/company_profiles/#{@company_profile.id}/crews", headers: @admin_headers

          assert_response :ok
        end

        test "create adds a pending crew member under the company" do
          position = create(:position)
          params = { crew: { crew_name: "Haji Muhammad Afiq", nationality: "Bruneian", position_id: position.id,
                             date_of_birth: "1995-01-01", ic_number: "00123456", gender: "Male",
                             foreign_worker_license_no: "FWL000123",
                             foreign_worker_license_start_date: "2026-01-01",
                             foreign_worker_license_end_date: "2027-01-01" } }

          assert_difference("CompaniesCrew.count", 1) do
            post "/api/v1/admin/company_profiles/#{@company_profile.id}/crews", params: params,
                                                                                headers: @admin_headers, as: :json
          end

          assert_response :created
          assert_equal({ "approval_status" => "pending", "status" => "active" },
                       response.parsed_body["data"].slice("approval_status", "status"))
        end

        test "create fails without the required fields" do
          params = { crew: { crew_name: "Incomplete Crew" } }

          assert_no_difference("CompaniesCrew.count") do
            post "/api/v1/admin/company_profiles/#{@company_profile.id}/crews", params: params,
                                                                                headers: @admin_headers, as: :json
          end

          assert_response :unprocessable_content
        end

        test "update changes crew details and reverts to pending" do
          crew = create(:companies_crew, :approved, company_profile: @company_profile)

          patch "/api/v1/admin/company_profiles/#{@company_profile.id}/crews/#{crew.id}",
                params: { crew: { status: "non_active" } }, headers: @admin_headers, as: :json

          assert_response :ok
          assert_equal "non_active", crew.reload.status
          assert_equal "pending", crew.approval_status
        end

        test "update fails when clearing a required field" do
          crew = create(:companies_crew, company_profile: @company_profile)

          patch "/api/v1/admin/company_profiles/#{@company_profile.id}/crews/#{crew.id}",
                params: { crew: { gender: "" } }, headers: @admin_headers, as: :json

          assert_response :unprocessable_content
        end

        test "destroy soft-deletes the crew member" do
          crew = create(:companies_crew, company_profile: @company_profile)

          delete "/api/v1/admin/company_profiles/#{@company_profile.id}/crews/#{crew.id}", headers: @admin_headers

          assert_response :ok
          assert_predicate crew.reload, :discarded?
        end
      end
    end
  end
end
