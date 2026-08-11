require "test_helper"

module Api
  module V1
    class CompanyProfilesControllerScopingTest < ActionDispatch::IntegrationTest
      setup do
        @password = "Password123!"
        @target = create(:company_profile)
      end

      test "non-officer requests are scoped to their own company profile" do
        own_company = create(:company_profile, company_name: "Viewer's Own Co", rocbn_no: "RC-VIEWER-OWN")
        headers = viewer_headers_for(own_company)

        get "/api/v1/fisherman/company_profiles/#{@target.id}", headers: headers

        assert_response :not_found

        get "/api/v1/fisherman/company_profiles", headers: headers

        assert_response :ok
        assert_equal [own_company.id], response.parsed_body["data"].pluck("id")
      end

      private

      def viewer_headers_for(company_profile)
        view_permission = Permission.find_or_create_by!(code: "profiling.view") { |p| p.name = "Profiling - View" }
        viewer_role = create(:role, :fisherman, company_profile: company_profile, permissions: [view_permission])
        viewer = create(:user, role: viewer_role, company_profile: company_profile,
                               ic_number: SecureRandom.hex(5), registration_type: "Commercial",
                               password: @password, password_confirmation: @password)
        auth_headers_for(viewer, password: @password)
      end
    end
  end
end
