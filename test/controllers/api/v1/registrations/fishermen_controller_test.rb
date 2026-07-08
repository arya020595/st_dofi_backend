require "test_helper"

module Api
  module V1
    module Registrations
      class FishermenControllerTest < ActionDispatch::IntegrationTest
        setup do
          @fisherman_role = create(:role, reference_id: "ROLE-003", name: "Fisherman")
        end

        test "create registers a commercial fisherman linked to the matching company profile" do
          company_profile = create(:company_profile, ic_no: "01-192839", registration_type: "Commercial")

          assert_difference("User.count", 1) do
            post "/api/v1/registrations/fisherman", params: { user: { name: "Muhammad Shahrizan Bin Haji Said",
                                                                      ic_number: "01-192839",
                                                                      registration_type: "Commercial",
                                                                      designation: "Owner" } }, as: :json
          end

          assert_response :created
          user = User.last

          assert_equal company_profile, user.company_profile
        end

        test "create sets status to pending and assigns the fisherman role" do
          create(:company_profile, ic_no: "01-192839", registration_type: "Commercial")

          post "/api/v1/registrations/fisherman", params: { user: { name: "Muhammad Shahrizan Bin Haji Said",
                                                                    ic_number: "01-192839",
                                                                    registration_type: "Commercial",
                                                                    designation: "Owner" } }, as: :json
          user = User.last

          assert_equal "pending", user.status
          assert_equal @fisherman_role, user.role
        end

        test "create derives designation from the matched company profile, ignoring the submitted value" do
          create(:company_profile, ic_no: "01-192839", registration_type: "Commercial", designation: "Owner")

          post "/api/v1/registrations/fisherman", params: { user: { name: "Muhammad Shahrizan Bin Haji Said",
                                                                    ic_number: "01-192839",
                                                                    registration_type: "Commercial",
                                                                    designation: "Admin" } }, as: :json

          assert_equal "Owner", User.last.designation
        end

        test "create rejects a commercial registration with no matching company profile" do
          assert_no_difference("User.count") do
            post "/api/v1/registrations/fisherman", params: { user: { name: "No Match", ic_number: "01-000000",
                                                                      registration_type: "Commercial",
                                                                      designation: "Owner" } }, as: :json
          end

          assert_response :not_found
        end

        test "create registers a small-scale full-time fisherman without a company profile" do
          assert_difference("User.count", 1) do
            post "/api/v1/registrations/fisherman", params: { user: { name: "Solo Fisherman",
                                                                      ic_number: "01-555555",
                                                                      registration_type:
                                                                         "Small - Scale (Full-Time)" } }, as: :json
          end

          assert_response :created
          assert_nil User.last.company_profile
        end

        test "create with an invalid registration_type returns errors" do
          post "/api/v1/registrations/fisherman", params: { user: { name: "Bad Type", ic_number: "01-123123",
                                                                    registration_type: "Not A Real Type" } },
                                                  as: :json

          assert_response :unprocessable_content
          assert_predicate response.parsed_body["errors"], :present?
        end
      end
    end
  end
end
