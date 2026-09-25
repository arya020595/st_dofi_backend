require "test_helper"

module Api
  module V1
    module Admin
      module ExternalUsers
        class FishermenControllerTest < ActionDispatch::IntegrationTest
          PATH = "/api/v1/admin/external_users/fishermen".freeze

          setup do
            @headers = officer_headers_for(permission_codes: %w[
                                             external_users.list external_users.view
                                             external_users.deactivate external_users.reactivate
                                           ])
            @fisherman = create(:user, :profiled_fisherman, fisherman_status: "active",
                                                            claimed_at: Time.current,
                                                            brunei_id_verified_at: Time.current)
            @inactive_fisherman = create(:user, :profiled_fisherman, status: "inactive",
                                                                     fisherman_status: "inactive")
            @jetty_manager = create(:user, :jetty_manager_shaped,
                                    role: create(:role, kind: Role::JETTY_MANAGER, name: "Jetty Manager"))
          end

          test "index lists only fisherman accounts" do
            get PATH, headers: @headers

            assert_response :ok
            assert_equal [@fisherman.id, @inactive_fisherman.id].sort, listed_ids.sort
          end

          test "active status filter excludes inactive fishermen" do
            get PATH, params: { q: { fisherman_status_eq: "active" } }, headers: @headers

            assert_response :ok
            assert_equal [@fisherman.id], listed_ids
          end

          test "show returns the fisherman detail" do
            get "#{PATH}/#{@fisherman.id}", headers: @headers

            assert_response :ok
            assert_equal "active", response.parsed_body.dig("data", "status")
          end

          test "deactivate makes an active fisherman inactive" do
            post "#{PATH}/#{@fisherman.id}/deactivate", headers: @headers

            assert_response :ok
            assert_equal "inactive", @fisherman.reload.fisherman_status
          end

          test "reactivate restores an inactive fisherman" do
            @fisherman.update!(status: "inactive", fisherman_status: "inactive")

            post "#{PATH}/#{@fisherman.id}/reactivate", headers: @headers

            assert_response :ok
            assert_equal "active", @fisherman.reload.fisherman_status
          end

          test "a jetty manager account is not reachable from the fisherman tab" do
            get "#{PATH}/#{@jetty_manager.id}", headers: @headers

            assert_response :not_found
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
