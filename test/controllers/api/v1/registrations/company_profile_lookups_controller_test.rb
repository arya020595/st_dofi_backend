require "test_helper"

module Api
  module V1
    module Registrations
      class CompanyProfileLookupsControllerTest < ActionDispatch::IntegrationTest
        test "create returns the matching contact's company details without authentication" do
          contact = create(:company_profile_contact, ic_no: "01-192839")
          lookup_token = ::Registrations::FishermanCompanyProfileLookupToken.generate("01-192839")

          post "/api/v1/registrations/fisherman/company_profile_lookup",
               params: { lookup_token: lookup_token }, as: :json

          assert_response :ok
          assert_equal contact.company_profile.company_name, response.parsed_body.dig("data", "company_name")
        end

        test "create includes designation so the FE can auto-select it on the registration form" do
          create(:company_profile_contact, ic_no: "01-192839", designation: "Admin")
          lookup_token = ::Registrations::FishermanCompanyProfileLookupToken.generate("01-192839")

          post "/api/v1/registrations/fisherman/company_profile_lookup",
               params: { lookup_token: lookup_token }, as: :json

          assert_equal "Admin", response.parsed_body.dig("data", "designation")
        end

        test "create returns not found when no contact matches the verified ic_no" do
          lookup_token = ::Registrations::FishermanCompanyProfileLookupToken.generate("00-000000")

          post "/api/v1/registrations/fisherman/company_profile_lookup",
               params: { lookup_token: lookup_token }, as: :json

          assert_response :not_found
          assert_equal "profiling_not_found", response.parsed_body["code"]
        end

        test "create ignores discarded contacts" do
          contact = create(:company_profile_contact, ic_no: "01-192839")
          contact.discard!
          lookup_token = ::Registrations::FishermanCompanyProfileLookupToken.generate("01-192839")

          post "/api/v1/registrations/fisherman/company_profile_lookup",
               params: { lookup_token: lookup_token }, as: :json

          assert_response :not_found
        end

        test "create returns unauthorized when lookup token is invalid" do
          post "/api/v1/registrations/fisherman/company_profile_lookup",
               params: { lookup_token: "invalid-token" }, as: :json

          assert_response :unauthorized
          assert_equal "invalid_lookup_token", response.parsed_body["code"]
        end
      end
    end
  end
end
