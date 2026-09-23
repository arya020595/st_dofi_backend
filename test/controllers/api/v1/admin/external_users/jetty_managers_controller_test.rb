require "test_helper"

module Api
  module V1
    module Admin
      module ExternalUsers
        class JettyManagersControllerTest < ActionDispatch::IntegrationTest
          PATH = "/api/v1/admin/external_users/jetty_managers".freeze
          IC_TAKEN = "IC number is already used by another user".freeze

          setup do
            @headers = officer_headers_for(permission_codes: %w[external_users.create])
            @jetty_role = create(:role, kind: Role::JETTY_MANAGER, name: "Jetty Manager")
            @jetty_manager = create(:user, :jetty_manager_shaped, role: @jetty_role, ic_number: "01-109878")
          end

          test "create provisions an active jetty manager without contact_no" do
            post PATH, params: { jetty_manager: new_attributes }, headers: @headers, as: :json

            assert_response :created
            user = User.find(response.parsed_body.dig("data", "id"))

            assert_equal [@jetty_role.id, "active", "01103989", nil],
                         [user.role_id, user.status, user.normalized_ic_number, user.contact_no]
            assert_predicate user.created_by, :officer?
          end

          test "create ignores role and status sent by the client" do
            post PATH, params: { jetty_manager: new_attributes.merge(role_id: create(:role).id, status: "pending") },
                       headers: @headers, as: :json

            assert_response :created
            user = User.find(response.parsed_body.dig("data", "id"))

            assert_equal [@jetty_role.id, "active"], [user.role_id, user.status]
          end

          test "create rejects an IC number already used by another kept user in any format" do
            post PATH, params: { jetty_manager: new_attributes(ic_number: "01109878") }, headers: @headers, as: :json

            assert_response :unprocessable_content
            assert_includes response.parsed_body.fetch("errors"), IC_TAKEN
          end

          test "create rejects an IC number held by a non jetty manager user" do
            fisherman = create(:user, :fins_governed_fisherman)

            post PATH, params: { jetty_manager: new_attributes(ic_number: fisherman.ic_number) },
                       headers: @headers, as: :json

            assert_response :unprocessable_content
            assert_includes response.parsed_body.fetch("errors"), IC_TAKEN
          end

          test "create reuses the IC number of a deleted user" do
            @jetty_manager.discard

            post PATH, params: { jetty_manager: new_attributes(ic_number: "01-109878") }, headers: @headers, as: :json

            assert_response :created
          end

          private

          def new_attributes(ic_number: "01-103989")
            { name: "Ahmad Firdaus bin Hassan", ic_number: ic_number, unit: "Docks", position: "Jetty Manager" }
          end
        end
      end
    end
  end
end
