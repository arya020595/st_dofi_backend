require "test_helper"

module Api
  module V1
    module Admin
      module ExternalUsers
        class JettyManagersLifecycleTest < ActionDispatch::IntegrationTest
          PATH = "/api/v1/admin/external_users/jetty_managers".freeze

          # A read + lifecycle officer: holds no create/update/delete, which the last test relies on.
          setup do
            @headers = officer_headers_for(permission_codes: %w[
                                             external_users.list external_users.view
                                             external_users.deactivate external_users.reactivate
                                           ])
            jetty_role = create(:role, kind: Role::JETTY_MANAGER, name: "Jetty Manager")
            @jetty_manager = create(:user, :jetty_manager_shaped, role: jetty_role)
            @inactive_jetty_manager = create(:user, :jetty_manager_shaped, role: jetty_role, status: "inactive")
            @fisherman = create(:user, :profiled_fisherman)
          end

          test "index lists only jetty manager accounts" do
            get PATH, headers: @headers

            assert_response :ok
            assert_equal [@jetty_manager.id, @inactive_jetty_manager.id].sort, listed_ids.sort
          end

          test "index filters by status" do
            get PATH, params: { q: { status_eq: "inactive" } }, headers: @headers

            assert_response :ok
            assert_equal [@inactive_jetty_manager.id], listed_ids
          end

          test "index finds an IC number typed with or without the dash" do
            dashless = @jetty_manager.ic_number.delete("-")

            [@jetty_manager.ic_number, dashless].each do |typed|
              get PATH, params: { q: { ic_number_or_normalized_ic_number_cont: typed } }, headers: @headers

              assert_equal [@jetty_manager.id], listed_ids, typed
            end
          end

          test "show returns the jetty manager detail" do
            get "#{PATH}/#{@jetty_manager.id}", headers: @headers

            assert_response :ok
            assert_equal "active", response.parsed_body.dig("data", "status")
          end

          test "deactivate makes an active jetty manager inactive" do
            post "#{PATH}/#{@jetty_manager.id}/deactivate", headers: @headers

            assert_response :ok
            assert_equal "inactive", @jetty_manager.reload.status
          end

          test "reactivate restores an inactive jetty manager" do
            post "#{PATH}/#{@inactive_jetty_manager.id}/reactivate", headers: @headers

            assert_response :ok
            assert_equal "active", @inactive_jetty_manager.reload.status
          end

          test "a fisherman account cannot be deactivated through the jetty manager tab" do
            post "#{PATH}/#{@fisherman.id}/deactivate", headers: @headers

            assert_response :not_found
          end

          test "create, update and delete each require their own external_users permission" do
            post PATH, params: { jetty_manager: { name: "X", ic_number: "01-999999", unit: "Docks", position: "P" } },
                       headers: @headers, as: :json

            assert_response :forbidden

            patch "#{PATH}/#{@jetty_manager.id}", params: { jetty_manager: { name: "X" } }, headers: @headers, as: :json

            assert_response :forbidden

            delete "#{PATH}/#{@jetty_manager.id}", headers: @headers

            assert_response :forbidden
          end

          private

          def listed_ids
            response.parsed_body.fetch("data").map { |row| row.fetch("id") }
          end
        end
      end
    end
  end
end
