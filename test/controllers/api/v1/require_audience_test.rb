require "test_helper"

module Api
  module V1
    class RequireAudienceTest < ActionDispatch::IntegrationTest
      setup do
        @password = "Password123!"

        profiling_permissions = %w[list view].map do |action|
          Permission.find_or_create_by!(code: "profiling.#{action}") { |p| p.name = "Profiling - #{action}" }
        end

        officer_role = create(:role, kind: Role::DOFI_OFFICER, permissions: profiling_permissions)
        jetty_manager_role = create(:role, kind: Role::JETTY_MANAGER, permissions: profiling_permissions)
        fisherman_role = create(:role, :fisherman, permissions: profiling_permissions)

        officer = create(:user, :officer_shaped, role: officer_role, password: @password,
                                                 password_confirmation: @password)
        jetty_manager = create(:user, :jetty_manager_shaped, role: jetty_manager_role, password: @password,
                                                             password_confirmation: @password)
        fisherman = create(:user, role: fisherman_role, ic_number: SecureRandom.hex(5),
                                  registration_type: "Commercial", password: @password,
                                  password_confirmation: @password)

        @officer_headers = auth_headers_for(officer, password: @password)
        @jetty_manager_headers = auth_headers_for(jetty_manager, password: @password)
        @fisherman_headers = auth_headers_for(fisherman, password: @password)
      end

      test "admin audience allows officer and jetty manager, denies fisherman" do
        get "/api/v1/admin/company_profiles", headers: @officer_headers

        assert_response :ok

        get "/api/v1/admin/company_profiles", headers: @jetty_manager_headers

        assert_response :ok

        get "/api/v1/admin/company_profiles", headers: @fisherman_headers

        assert_response :forbidden
      end

      test "fisherman audience allows only fisherman" do
        get "/api/v1/fisherman/company_profiles", headers: @fisherman_headers

        assert_response :ok

        get "/api/v1/fisherman/company_profiles", headers: @officer_headers

        assert_response :forbidden

        get "/api/v1/fisherman/company_profiles", headers: @jetty_manager_headers

        assert_response :forbidden
      end

      test "routes without an audience default are unaffected by the gate" do
        get "/api/v1/permissions", headers: @fisherman_headers

        assert_response :ok

        get "/api/v1/permissions", headers: @officer_headers

        assert_response :ok
      end
    end
  end
end
