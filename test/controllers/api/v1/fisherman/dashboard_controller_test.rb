require "test_helper"

module Api
  module V1
    module Fisherman
      # rubocop:disable Metrics/ClassLength
      class DashboardControllerTest < ActionDispatch::IntegrationTest
        setup do
          @company_profile = create(:company_profile)
          @manifest = create(:manifest, company_profile: @company_profile)
          @headers = fisherman_headers_for(@manifest, permission_codes: %w[manifest_list.list])
          @zone = create(:zone, name: "Zone Alpha")
          @gear_master = create(:fishing_gear, name: "Drift Gill Net", gear_type: "Net")
          @gear = create(
            :companies_fishing_gear,
            :approved,
            company_profile: @company_profile,
            companies_vessel: @manifest.companies_vessel,
            fishing_gear: @gear_master
          )

          first_report = create(:capture_report, manifest: @manifest, capture_report_status: "verified",
                                                 reviewed_at: Time.zone.parse("2026-08-05 10:00:00"),
                                                 zone: @zone, zone_area: @zone.name)
          second_manifest = create(:manifest, company_profile: @company_profile)
          second_report = create(:capture_report, manifest: second_manifest, capture_report_status: "verified",
                                                  reviewed_at: Time.zone.parse("2026-08-07 11:00:00"),
                                                  zone: @zone, zone_area: @zone.name)
          out_of_range_report = create(:capture_report, manifest: @manifest, capture_report_status: "verified",
                                                        reviewed_at: Time.zone.parse("2026-07-01 09:00:00"),
                                                        zone: @zone, zone_area: @zone.name)
          other_company_report = create(:capture_report, capture_report_status: "verified",
                                                         reviewed_at: Time.zone.parse("2026-08-06 10:00:00"),
                                                         zone: @zone, zone_area: @zone.name)

          first_gear_detail = create(:fishing_gear_detail, capture_report: first_report, companies_fishing_gear: @gear,
                                                           name: "Drift Gill Net", gear_type: "Net")
          second_gear_detail = create(
            :fishing_gear_detail,
            capture_report: second_report,
            companies_fishing_gear: @gear,
            name: "Drift Gill Net",
            gear_type: "Net"
          )
          out_of_range_gear_detail = create(:fishing_gear_detail, capture_report: out_of_range_report,
                                                                  companies_fishing_gear: @gear,
                                                                  name: "Drift Gill Net", gear_type: "Net")
          create(:fishing_gear_detail, capture_report: other_company_report, name: "Other Gear", gear_type: "Trap")

          tuna = create(:dictionary, local_name: "Tuna", scientific_name: "Thunnus")
          snapper = create(:dictionary, local_name: "Snapper", scientific_name: "Lutjanus")

          create(:fish_capture_detail, capture_report: first_report, fishing_gear_detail: first_gear_detail,
                                       dictionary: tuna, local_name: "Tuna", scientific_name: "Thunnus",
                                       amount_captured_kg: 10, overall_total: 100)
          create(:fish_capture_detail, capture_report: second_report, fishing_gear_detail: second_gear_detail,
                                       dictionary: tuna, local_name: "Tuna", scientific_name: "Thunnus",
                                       amount_captured_kg: 5, overall_total: 60)
          create(:fish_capture_detail, capture_report: second_report, fishing_gear_detail: second_gear_detail,
                                       dictionary: snapper, local_name: "Snapper", scientific_name: "Lutjanus",
                                       amount_captured_kg: 7, overall_total: 84)
          create(
            :fish_capture_detail,
            capture_report: out_of_range_report,
            fishing_gear_detail: out_of_range_gear_detail,
            dictionary: tuna,
            local_name: "Tuna",
            scientific_name: "Thunnus",
            amount_captured_kg: 99,
            overall_total: 999
          )
          create(:fish_capture_detail, capture_report: other_company_report, dictionary: tuna, local_name: "Tuna",
                                       scientific_name: "Thunnus", amount_captured_kg: 88, overall_total: 880)
        end

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

        test "dashboard endpoints require manifest list permission" do
          no_access_headers = fisherman_headers_for(@manifest, permission_codes: [])

          get "/api/v1/fisherman/dashboard/summary", headers: no_access_headers

          assert_response :forbidden
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
      # rubocop:enable Metrics/ClassLength
    end
  end
end
