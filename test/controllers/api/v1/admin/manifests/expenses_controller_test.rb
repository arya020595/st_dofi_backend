require "test_helper"

module Api
  module V1
    module Admin
      module Manifests
        class ExpensesControllerTest < ActionDispatch::IntegrationTest
          setup do
            @manifest = create(:manifest)
            @headers = officer_headers_for(permission_codes: %w[manifest_expenses.view])
          end

          test "show returns the expense for the manifest" do
            create(:manifest_expense, manifest: @manifest, fuel_litres: 120.0)

            get "/api/v1/admin/manifests/#{@manifest.id}/expense", headers: @headers

            assert_response :ok
            assert_in_delta(120.0, response.parsed_body["data"]["fuel_litres"].to_f)
          end

          test "show returns not_found when no expense exists yet" do
            get "/api/v1/admin/manifests/#{@manifest.id}/expense", headers: @headers

            assert_response :not_found
          end
        end
      end
    end
  end
end
