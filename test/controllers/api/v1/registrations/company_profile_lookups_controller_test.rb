require "test_helper"

module Api
  module V1
    module Registrations
      class CompanyProfileLookupsControllerTest < ActionDispatch::IntegrationTest
        test "show returns the matching company profile without authentication" do
          company_profile = create(:company_profile, ic_no: "01-192839")

          get "/api/v1/registrations/fisherman/company_profile", params: { ic_no: "01-192839" }

          assert_response :ok
          assert_equal company_profile.company_name, response.parsed_body.dig("data", "company_name")
        end

        test "show returns not found when no company profile matches the ic_no" do
          get "/api/v1/registrations/fisherman/company_profile", params: { ic_no: "00-000000" }

          assert_response :not_found
        end

        test "show ignores discarded company profiles" do
          company_profile = create(:company_profile, ic_no: "01-192839")
          company_profile.discard!

          get "/api/v1/registrations/fisherman/company_profile", params: { ic_no: "01-192839" }

          assert_response :not_found
        end
      end
    end
  end
end
