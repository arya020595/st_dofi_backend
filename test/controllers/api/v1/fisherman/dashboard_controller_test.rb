require "test_helper"

module Api
  module V1
    module Fisherman
      module DashboardControllerTestSetup
        def setup
          super

          create_dashboard_context
          create_reports
          create_gear_details
          create_fish_details
        end

        def create_dashboard_context
          @company_profile = create(:company_profile)
          @manifest = create(:manifest, company_profile: @company_profile)
          @headers = fisherman_headers_for(@manifest, permission_codes: %w[manifest.view])
          @zone = create(:zone, name: "Zone Alpha")
          @gear_master = create(:fishing_gear, name: "Drift Gill Net", gear_type: "Net")
          @gear = create_company_gear
        end

        def create_company_gear
          create(:companies_fishing_gear, :approved, company_profile: @company_profile,
                                                     companies_vessel: @manifest.companies_vessel,
                                                     fishing_gear: @gear_master)
        end

        def create_reports
          second_manifest = create(:manifest, company_profile: @company_profile)
          @first_report = verified_report(@manifest, "2026-08-05 10:00:00")
          @second_report = verified_report(second_manifest, "2026-08-07 11:00:00")
          @out_of_range_report = verified_report(@manifest, "2026-07-01 09:00:00")
          @other_company_report = verified_report(create(:manifest), "2026-08-06 10:00:00")
        end

        def verified_report(manifest, reviewed_at)
          create(:capture_report, manifest: manifest, capture_report_status: "verified",
                                  reviewed_at: Time.zone.parse(reviewed_at), zone: @zone, zone_area: @zone.name)
        end

        def create_gear_details
          @first_gear_detail = gear_detail(@first_report)
          @second_gear_detail = gear_detail(@second_report)
          @out_of_range_gear_detail = gear_detail(@out_of_range_report)
          create(:fishing_gear_detail, capture_report: @other_company_report, name: "Other Gear", gear_type: "Trap")
        end

        def gear_detail(report)
          create(:fishing_gear_detail, capture_report: report, companies_fishing_gear: @gear,
                                       name: "Drift Gill Net", gear_type: "Net")
        end

        def create_fish_details
          tuna = create(:dictionary, local_name: "Tuna", scientific_name: "Thunnus")
          snapper = create(:dictionary, local_name: "Snapper", scientific_name: "Lutjanus")
          create_primary_fish_details(tuna, snapper)
          create_out_of_scope_fish_details(tuna)
        end

        def create_primary_fish_details(tuna, snapper)
          create(:fish_capture_detail, capture_report: @first_report, fishing_gear_detail: @first_gear_detail,
                                       dictionary: tuna, local_name: "Tuna", scientific_name: "Thunnus",
                                       amount_captured_kg: 10, overall_total: 100)
          create(:fish_capture_detail, capture_report: @second_report, fishing_gear_detail: @second_gear_detail,
                                       dictionary: tuna, local_name: "Tuna", scientific_name: "Thunnus",
                                       amount_captured_kg: 5, overall_total: 60)
          create(:fish_capture_detail, capture_report: @second_report, fishing_gear_detail: @second_gear_detail,
                                       dictionary: snapper, local_name: "Snapper", scientific_name: "Lutjanus",
                                       amount_captured_kg: 7, overall_total: 84)
        end

        def create_out_of_scope_fish_details(tuna)
          create_out_of_range_fish_detail(tuna)
          create(:fish_capture_detail, capture_report: @other_company_report, dictionary: tuna, local_name: "Tuna",
                                       scientific_name: "Thunnus", amount_captured_kg: 88, overall_total: 880)
        end

        def create_out_of_range_fish_detail(tuna)
          create(
            :fish_capture_detail,
            capture_report: @out_of_range_report,
            fishing_gear_detail: @out_of_range_gear_detail,
            dictionary: tuna,
            local_name: "Tuna",
            scientific_name: "Thunnus",
            amount_captured_kg: 99,
            overall_total: 999
          )
        end

        private

        def assert_summary_payload(data)
          assert_equal 2, data["total_trips"]

          assert_in_delta 22.0, data["total_catch_kg"]
          assert_in_delta 244.0, data["estimated_revenue"]
          assert_in_delta 11.0, data["catch_per_unit_effort"]
        end

        def assert_fishing_gear_payload(data)
          first_item = data.first

          assert_equal 1, data.size
          assert_equal [@gear.id, @gear_master.id, "Drift Gill Net", "Net"],
                       first_item.values_at("companies_fishing_gear_id", "fishing_gear_id", "name", "gear_type")

          assert_in_delta 22.0, first_item["total_catch_kg"]
        end
      end

      class DashboardControllerTest < ActionDispatch::IntegrationTest
        include DashboardControllerTestSetup

        test "summary returns catch totals, estimated revenue, total trips, and cpue within the reviewed date range" do
          get "/api/v1/fisherman/dashboard/summary",
              params: { start_date: "2026-08-01", end_date: "2026-08-10" }, headers: @headers

          assert_response :ok

          assert_summary_payload(response.parsed_body["data"])
        end

        test "top_fishes returns aggregated fish rows for the chart" do
          get "/api/v1/fisherman/dashboard/top_fishes",
              params: { start_date: "2026-08-01", end_date: "2026-08-10" }, headers: @headers

          assert_response :ok

          assert_equal [
            { "dictionary_id" => Dictionary.find_by!(local_name: "Tuna").id, "local_name" => "Tuna",
              "scientific_name" => "Thunnus", "total_catch_kg" => 15.0 },
            { "dictionary_id" => Dictionary.find_by!(local_name: "Snapper").id, "local_name" => "Snapper",
              "scientific_name" => "Lutjanus", "total_catch_kg" => 7.0 }
          ], response.parsed_body["data"]
        end

        test "fishing_gear_analytics returns aggregated catch by profiling fishing gear" do
          get "/api/v1/fisherman/dashboard/fishing_gear_analytics",
              params: { start_date: "2026-08-01", end_date: "2026-08-10" }, headers: @headers

          assert_response :ok

          assert_fishing_gear_payload(response.parsed_body["data"])
        end

        test "zone_analytics returns aggregated catch by zone" do
          get "/api/v1/fisherman/dashboard/zone_analytics",
              params: { start_date: "2026-08-01", end_date: "2026-08-10" }, headers: @headers

          assert_response :ok
          assert_equal [{ "zone_id" => @zone.id, "zone_area" => "Zone Alpha", "total_catch_kg" => 22.0 }],
                       response.parsed_body["data"]
        end

        test "dashboard endpoints require manifest permission" do
          no_access_headers = fisherman_headers_for(@manifest, permission_codes: [])

          get "/api/v1/fisherman/dashboard/summary", headers: no_access_headers

          assert_response :forbidden
        end
      end
    end
  end
end
