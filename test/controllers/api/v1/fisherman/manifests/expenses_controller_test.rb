require "test_helper"

module Api
  module V1
    module Fisherman
      module Manifests
        class ExpensesControllerTest < ActionDispatch::IntegrationTest
          setup do
            @manifest = create(:manifest)
            @headers = fisherman_headers_for(@manifest,
                                             permission_codes: %w[manifest_expenses.view manifest_expenses.create
                                                                  manifest_expenses.update])
          end

          test "create upserts the expense record" do
            params = { expense: { fuel_litres: 120.0, fuel_bnd: 180.0, ice_litres: 80.0, ice_bnd: 24.0,
                                  ration_bnd: 35.0 } }

            post "/api/v1/fisherman/manifests/#{@manifest.id}/expense", params: params, headers: @headers, as: :json

            assert_response :ok
            assert_predicate @manifest.reload.manifest_expense, :present?
          end

          test "update modifies the existing expense without creating a duplicate" do
            create(:manifest_expense, manifest: @manifest, fuel_litres: 50.0)

            assert_no_difference("ManifestExpense.count") do
              patch "/api/v1/fisherman/manifests/#{@manifest.id}/expense",
                    params: { expense: { fuel_litres: 200.0 } }, headers: @headers, as: :json
            end

            assert_response :ok
            assert_in_delta(200.0, @manifest.reload.manifest_expense.fuel_litres)
          end

          test "show returns not_found when no expense exists yet" do
            get "/api/v1/fisherman/manifests/#{@manifest.id}/expense", headers: @headers

            assert_response :not_found
          end
        end
      end
    end
  end
end
