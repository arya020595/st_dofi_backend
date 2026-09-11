require "test_helper"

module Api
  module V1
    module Admin
      class AccountsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"
          @permissions = create_account_permissions
          @officer = create_officer
          @headers = auth_headers_for(@officer, password: @password)
          @fisherman = create_fisherman_account
          @jetty_manager = create_jetty_manager_account
        end

        test "index filters fisherman accounts by category" do
          get "/api/v1/admin/accounts", params: { category: "fisherman_account" }, headers: @headers

          assert_response :ok
          assert_equal [@fisherman.id], account_ids
        end

        test "index filters jetty manager accounts by category" do
          get "/api/v1/admin/accounts", params: { category: "jetty_manager_account" }, headers: @headers

          assert_response :ok
          assert_equal [@jetty_manager.id], account_ids
        end

        test "index filters the category by active lifecycle status" do
          @fisherman.update!(fisherman_status: "active", claimed_at: Time.current, brunei_id_verified_at: Time.current)

          get "/api/v1/admin/accounts", params: { category: "fisherman_account", status: "active" }, headers: @headers

          assert_response :ok
          assert_equal [@fisherman.id], account_ids
        end

        test "index accepts multiple lifecycle status values" do
          @fisherman.update!(fisherman_status: "active", claimed_at: Time.current, brunei_id_verified_at: Time.current)
          @jetty_manager.update!(status: "inactive")

          get "/api/v1/admin/accounts", params: { status: "active,inactive" }, headers: @headers

          assert_response :ok
          assert_equal [@fisherman.id, @jetty_manager.id].sort, account_ids.sort
        end

        test "show returns the account category and lifecycle status" do
          get "/api/v1/admin/accounts/#{@fisherman.id}", headers: @headers

          assert_response :ok
          assert_equal "fisherman_account", response.parsed_body.dig("data", "category")
        end

        test "deactivate suspends a fisherman account" do
          @fisherman.update!(fisherman_status: "active", claimed_at: Time.current, brunei_id_verified_at: Time.current)

          post "/api/v1/admin/accounts/#{@fisherman.id}/deactivate", headers: @headers

          assert_response :ok
          assert_equal "suspended", @fisherman.reload.fisherman_status
        end

        test "reactivate activates an inactive jetty manager account" do
          @jetty_manager.update!(status: "inactive")

          post "/api/v1/admin/accounts/#{@jetty_manager.id}/reactivate", headers: @headers

          assert_response :ok
          assert_equal "active", @jetty_manager.reload.status
        end

        private

        def create_account_permissions
          %w[fisherman_approvals jetty_manager_approvals].flat_map do |resource|
            %w[list view deactivate reactivate].map do |action|
              Permission.find_or_create_by!(code: "#{resource}.#{action}") do |permission|
                permission.name = permission.code
              end
            end
          end
        end

        def create_officer
          role = create(:role, kind: Role::DOFI_OFFICER, permissions: @permissions)
          create(:user, role:, position: "Administrator", unit: "HQ", password: @password,
                        password_confirmation: @password)
        end

        def create_fisherman_account
          profile = create(:company_profile)
          role = create(:role, :fisherman, company_profile: profile, is_default: true, name: "Owner")
          create(:user, role:, company_profile: profile, ic_number: "01-701001", registration_type: "Commercial",
                        provisioning_source: ::Fisherman::ProvisionUser::DOFI_COMPANY_PROFILE)
        end

        def create_jetty_manager_account
          role = create(:role, kind: Role::JETTY_MANAGER, name: "Jetty Manager")
          create(:user, role:, ic_number: "31-701001", unit: "Muara Port", position: "Jetty Manager",
                        contact_no: "7190001")
        end

        def account_ids
          response.parsed_body.fetch("data").map { |account| account.fetch("id") }
        end
      end
    end
  end
end
