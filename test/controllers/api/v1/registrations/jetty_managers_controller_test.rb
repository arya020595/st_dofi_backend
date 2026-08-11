require "test_helper"

module Api
  module V1
    module Registrations
      class JettyManagersControllerTest < ActionDispatch::IntegrationTest
        setup do
          @jetty_manager_role = create(:role, kind: Role::JETTY_MANAGER, name: "Jetty Manager")
        end

        test "create registers a new jetty manager without authentication" do
          assert_difference("User.count", 1) do
            post "/api/v1/registrations/jetty_manager", params: { user: { name: "Amiirul Azri Mizamuddin",
                                                                          ic_number: "01-1234567", unit: "Docks",
                                                                          position: "Jetty Supervisor",
                                                                          contact_no: "71111111" } }, as: :json
          end

          assert_response :created
        end

        test "create assigns the jetty manager role and marks brunei id as verified" do
          post "/api/v1/registrations/jetty_manager", params: { user: { name: "Amiirul Azri Mizamuddin",
                                                                        ic_number: "01-1234567", unit: "Docks",
                                                                        position: "Jetty Supervisor",
                                                                        contact_no: "71111111" } }, as: :json
          user = User.last

          assert_equal @jetty_manager_role, user.role
          assert_predicate user, :brunei_id_verified_at?
        end

        test "create sets status to pending, requiring officer approval" do
          post "/api/v1/registrations/jetty_manager", params: { user: { name: "Amiirul Azri Mizamuddin",
                                                                        ic_number: "01-1234567", unit: "Docks",
                                                                        position: "Jetty Supervisor",
                                                                        contact_no: "71111111" } }, as: :json

          assert_equal "pending", User.last.status
        end

        test "create is forbidden to neither require nor accept an Authorization header" do
          post "/api/v1/registrations/jetty_manager", params: { user: { name: "x", ic_number: "01-0000001",
                                                                        unit: "Docks", position: "Jetty Supervisor",
                                                                        contact_no: "71111111" } }, as: :json

          assert_response :created
        end

        test "create rejects a duplicate ic_number" do
          post "/api/v1/registrations/jetty_manager", params: { user: { name: "First", ic_number: "01-9999999",
                                                                        unit: "Docks", position: "Jetty Supervisor",
                                                                        contact_no: "71111111" } }, as: :json

          assert_no_difference("User.count") do
            post "/api/v1/registrations/jetty_manager", params: { user: { name: "Second", ic_number: "01-9999999",
                                                                          unit: "Docks",
                                                                          position: "Jetty Supervisor",
                                                                          contact_no: "71111112" } }, as: :json
          end

          assert_response :unprocessable_content
        end

        test "create with missing required fields returns errors" do
          post "/api/v1/registrations/jetty_manager", params: { user: { name: "No Details" } }, as: :json

          assert_response :unprocessable_content
          assert_predicate response.parsed_body["errors"], :present?
        end

        test "create re-registers a rejected jetty manager by updating the existing record back to pending" do
          rejected_user = create(:user, role: @jetty_manager_role, status: "rejected", ic_number: "01-8888888",
                                        name: "Old Jetty Manager", unit: "Old Unit", position: "Old Position",
                                        contact_no: "79999999", rejection_reason: "Incomplete data")

          assert_no_difference("User.count") do
            post "/api/v1/registrations/jetty_manager",
                 params: { user: { name: "Updated Jetty Manager", ic_number: "01-8888888", unit: "Lumut Port",
                                   position: "Jetty Supervisor", contact_no: "71112222" } }, as: :json
          end

          assert_response :created
          rejected_user.reload

          assert_reregistered_jetty_manager(rejected_user)
        end

        private

        def assert_reregistered_jetty_manager(user)
          assert_equal "pending", user.status
          assert_nil user.rejection_reason

          assert_equal ["Updated Jetty Manager", "Lumut Port"],
                       [user.name, user.unit]
          assert_equal ["Jetty Supervisor", "71112222"],
                       [user.position, user.contact_no]
        end
      end
    end
  end
end
