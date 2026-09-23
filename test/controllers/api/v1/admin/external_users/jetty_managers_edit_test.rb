require "test_helper"

module Api
  module V1
    module Admin
      module ExternalUsers
        class JettyManagersEditTest < ActionDispatch::IntegrationTest
          PATH = "/api/v1/admin/external_users/jetty_managers".freeze

          setup do
            @headers = officer_headers_for(permission_codes: %w[external_users.update external_users.delete])
            jetty_role = create(:role, kind: Role::JETTY_MANAGER, name: "Jetty Manager")
            @jetty_manager = create(:user, :jetty_manager_shaped, role: jetty_role, ic_number: "01-109878")
            create(:user, :jetty_manager_shaped, role: jetty_role, ic_number: "01-300300")
          end

          test "update edits profile fields and the IC number" do
            patch "#{PATH}/#{@jetty_manager.id}",
                  params: { jetty_manager: { name: "Renamed", position: "Jetty Manager", ic_number: "01-200200" } },
                  headers: @headers, as: :json

            assert_response :ok
            assert_equal ["Renamed", "Jetty Manager", "01200200"],
                         @jetty_manager.reload.values_at(:name, :position, :normalized_ic_number)
          end

          test "update keeps the user's own IC number valid" do
            patch "#{PATH}/#{@jetty_manager.id}", params: { jetty_manager: { ic_number: "01109878", unit: "Muara" } },
                                                  headers: @headers, as: :json

            assert_response :ok
            assert_equal "Muara", @jetty_manager.reload.unit
          end

          test "update rejects an IC number used by another user" do
            patch "#{PATH}/#{@jetty_manager.id}", params: { jetty_manager: { ic_number: "01-300300" } },
                                                  headers: @headers, as: :json

            assert_response :unprocessable_content
            assert_includes response.parsed_body.fetch("errors"), "IC number is already used by another user"
            assert_equal "01109878", @jetty_manager.reload.normalized_ic_number
          end

          test "destroy soft deletes the jetty manager and frees its IC number" do
            delete "#{PATH}/#{@jetty_manager.id}", headers: @headers

            assert_response :ok
            assert_predicate @jetty_manager.reload, :discarded?
            assert_predicate build(:user, ic_number: "01-109878"), :valid?
          end

          test "fisherman and officer accounts are not reachable from the jetty manager tab" do
            fisherman = create(:user, :fins_governed_fisherman)
            officer = create(:user, :officer_shaped, role: create(:role))

            patch "#{PATH}/#{fisherman.id}", params: { jetty_manager: { name: "X" } }, headers: @headers, as: :json

            assert_response :not_found

            delete "#{PATH}/#{officer.id}", headers: @headers

            assert_response :not_found
          end
        end
      end
    end
  end
end
