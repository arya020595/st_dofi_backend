require "test_helper"

module Api
  module V1
    module Registrations
      class FishermenControllerTest < ActionDispatch::IntegrationTest
        setup do
          @fisherman_role = create(:role, kind: Role::FISHERMAN, name: "Fisherman")
        end

        test "create registers a commercial fisherman linked to the matching company profile" do
          contact = create(:company_profile_contact, ic_no: "01-192839",
                                                     company_profile: create(:company_profile,
                                                                             registration_type: "Commercial"))

          assert_difference("User.count", 1) do
            post "/api/v1/registrations/fisherman", params: { user: { name: "Muhammad Shahrizan Bin Haji Said",
                                                                      ic_number: "01-192839",
                                                                      registration_type: "Commercial",
                                                                      designation: "Owner" } }, as: :json
          end

          assert_response :created
          user = User.last

          assert_equal contact.company_profile, user.company_profile
        end

        test "create sets status to pending and assigns the fisherman role" do
          create(:company_profile_contact, ic_no: "01-192839",
                                           company_profile: create(:company_profile, registration_type: "Commercial"))

          post "/api/v1/registrations/fisherman", params: { user: { name: "Muhammad Shahrizan Bin Haji Said",
                                                                    ic_number: "01-192839",
                                                                    registration_type: "Commercial",
                                                                    designation: "Owner" } }, as: :json
          user = User.last

          assert_equal "pending", user.status
          assert_equal @fisherman_role, user.role
        end

        test "create derives designation from the matched company profile, ignoring the submitted value" do
          create(:company_profile_contact, ic_no: "01-192839", designation: "Owner",
                                           company_profile: create(:company_profile, registration_type: "Commercial"))

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
          assert_equal "No company contact matches this IC number.", response.parsed_body["message"]
        end

        test "create registers a small-scale full-time fisherman linked to their pre-profiled individual profile" do
          contact = create(:company_profile_contact, ic_no: "01-555555", designation: "Owner",
                                                     company_profile: create(:company_profile, :individual))

          assert_difference("User.count", 1) do
            post "/api/v1/registrations/fisherman", params: { user: { name: "Solo Fisherman",
                                                                      ic_number: "01-555555",
                                                                      registration_type:
                                                                         "Small - Scale (Full-Time)" } }, as: :json
          end

          assert_response :created
          assert_equal contact.company_profile, User.last.company_profile
        end

        test "create rejects a small-scale full-time registration with no matching company profile" do
          assert_no_difference("User.count") do
            post "/api/v1/registrations/fisherman", params: { user: { name: "No Match", ic_number: "01-555999",
                                                                      registration_type:
                                                                         "Small - Scale (Full-Time)" } }, as: :json
          end

          assert_response :not_found
          assert_equal "No company contact matches this IC number.", response.parsed_body["message"]
        end

        test "create with an invalid registration_type returns errors" do
          post "/api/v1/registrations/fisherman", params: { user: { name: "Bad Type", ic_number: "01-123123",
                                                                    registration_type: "Not A Real Type" } },
                                                  as: :json

          assert_response :unprocessable_content
          assert_predicate response.parsed_body["errors"], :present?
        end

        test "create re-registers a rejected fisherman by updating the existing record back to pending" do
          contact = create(:company_profile_contact, ic_no: "01-777777", designation: "Owner",
                                                     company_profile: create(:company_profile, :individual))
          rejected_user = create(:user, role: @fisherman_role, status: "rejected", ic_number: "01-777777",
                                        name: "Old Name", registration_type: "Small - Scale (Part-Time)",
                                        rejection_reason: "Incomplete profile")

          assert_no_difference("User.count") do
            post "/api/v1/registrations/fisherman",
                 params: { user: { name: "Updated Fisherman", ic_number: "01-777777",
                                   registration_type: "Small - Scale (Full-Time)" } }, as: :json
          end

          assert_response :created
          rejected_user.reload

          assert_reregistered_fisherman(rejected_user, contact)
        end

        private

        def assert_reregistered_fisherman(user, contact)
          assert_equal "pending", user.status
          assert_nil user.rejection_reason
          assert_equal "Owner", user.designation

          assert_equal ["Updated Fisherman", "Small - Scale (Full-Time)"],
                       [user.name, user.registration_type]
          assert_equal [contact.company_profile, contact],
                       [user.company_profile, user.company_profile_contact]
        end
      end
    end
  end
end
