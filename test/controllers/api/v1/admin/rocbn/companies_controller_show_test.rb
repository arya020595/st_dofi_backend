require "test_helper"

module Api
  module V1
    module Admin
      module Rocbn
        class CompaniesControllerShowTest < ActionDispatch::IntegrationTest
          include RocbnTestSupport

          PATH = "/api/v1/admin/rocbn/companies".freeze
          DETAIL_KEYS = %w[company_address company_name contact_number district id mukim rocbn_number village].freeze

          setup do
            @headers = officer_headers_for(permission_codes: %w[rocbn_companies.list rocbn_companies.view])
          end

          test "returns the fields Add Profiling autofills, from the registry's columns" do
            company = insert_rocbn_company(registration_no: "RCDETAIL1", name: "DETAIL CO", address_1: "No. 1077",
                                           address_2: "Kuala Belait", telp: "3331077", district: "Belait",
                                           mukim: "Kuala Belait", village: "Kg Mumong", contact: "mail@example.com")

            get "#{PATH}/#{company.id}", headers: @headers

            assert_response :ok
            assert_equal({ "id" => company.id.to_s, "rocbn_number" => "RCDETAIL1", "company_name" => "DETAIL CO",
                           "company_address" => "No. 1077, Kuala Belait", "contact_number" => "3331077",
                           "district" => "Belait", "mukim" => "Kuala Belait", "village" => "Kg Mumong" },
                         response.parsed_body["data"])
          end

          test "a value the registry does not provide is null, never its placeholder" do
            company = insert_rocbn_company(mukim: "-", village: "Not Specified", district: "N/A", telp: "-")

            get "#{PATH}/#{company.id}", headers: @headers

            data = response.parsed_body["data"]

            assert_equal [nil, nil, nil, nil], data.values_at("mukim", "village", "district", "contact_number")
          end

          test "returns the company that was selected, not one with a similar name" do
            insert_rocbn_company(name: "AMIIRUL FISH CO.")
            selected = insert_rocbn_company(name: "FISH AMIIRUL SDN. BHD.")

            get "#{PATH}/#{selected.id}", headers: @headers

            assert_equal "FISH AMIIRUL SDN. BHD.", response.parsed_body.dig("data", "company_name")
          end

          test "exposes nothing about the directors and shareholders on the row" do
            company = insert_rocbn_company
            ::Rocbn::Company.lease_connection.execute(
              "UPDATE sync_rocbn_hotel SET person_name = 'Jane Director', identity_number = '00-123456' " \
              "WHERE id = #{company.id.to_i}"
            )

            get "#{PATH}/#{company.id}", headers: @headers

            assert_equal DETAIL_KEYS, response.parsed_body["data"].keys.sort
            assert_no_match(/Jane Director|00-123456/, response.body)
          end

          test "an unknown or soft-deleted company is not found" do
            deleted = insert_rocbn_company(deleted_at: Time.utc(2026, 1, 1))

            [0, 123_456_789_012, deleted.id].each do |id|
              get "#{PATH}/#{id}", headers: @headers

              assert_response :not_found, "expected id #{id} to be not found"
            end
          end

          test "an id that is not a number never reaches the database" do
            get "#{PATH}/1%20OR%201=1", headers: @headers

            assert_response :not_found
          end

          test "the view permission is required" do
            company = insert_rocbn_company
            list_only = create(:role, permissions: find_or_create_permissions(%w[rocbn_companies.list]))
            user = create(:user, role: list_only, password: "Password123!", password_confirmation: "Password123!")

            get "#{PATH}/#{company.id}", headers: auth_headers_for(user, password: "Password123!")

            assert_response :forbidden
          end
        end
      end
    end
  end
end
