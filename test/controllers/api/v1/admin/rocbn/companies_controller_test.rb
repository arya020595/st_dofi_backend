require "test_helper"

module Api
  module V1
    module Admin
      module Rocbn
        class CompaniesControllerTest < ActionDispatch::IntegrationTest
          include RocbnTestSupport

          PATH = "/api/v1/admin/rocbn/companies".freeze
          LIST_KEYS = %w[company_address company_name id rocbn_number].freeze

          setup do
            @headers = officer_headers_for(permission_codes: %w[rocbn_companies.list rocbn_companies.view])
          end

          test "searches by part of the company name, ignoring case" do
            insert_rocbn_company(name: "AMIIRUL FISH CO.")
            insert_rocbn_company(name: "SERI BAHARI FISHERIES")

            get PATH, params: { q: { company_name_cont: "amiirul" } }, headers: @headers

            assert_response :ok
            assert_equal ["AMIIRUL FISH CO."], listed("company_name")
          end

          test "searches by ROCBN number, exactly" do
            insert_rocbn_company(registration_no: "RCEXACT1", name: "ONE CO")
            insert_rocbn_company(registration_no: "RCEXACT12", name: "TWO CO")

            get PATH, params: { q: { rocbn_number_eq: "rcexact1" } }, headers: @headers

            assert_equal ["ONE CO"], listed("company_name")
          end

          test "both criteria together narrow the result" do
            insert_rocbn_company(registration_no: "RCBOTH1", name: "AMIIRUL ONE")
            insert_rocbn_company(registration_no: "RCBOTH2", name: "AMIIRUL TWO")

            get PATH, params: { q: { company_name_cont: "amiirul", rocbn_number_eq: "RCBOTH2" } }, headers: @headers

            assert_equal ["AMIIRUL TWO"], listed("company_name")
          end

          test "lists only what the Search Company table shows, with the id as a string" do
            insert_rocbn_company(name: "LISTED CO", address_1: "No. 1", address_2: "-", address_3: "Kuala Belait")

            get PATH, params: { q: { company_name_cont: "listed" } }, headers: @headers

            row = response.parsed_body["data"].first

            assert_equal LIST_KEYS, row.keys.sort
            assert_equal ["No. 1, Kuala Belait", String], [row["company_address"], row["id"].class]
          end

          test "pages in a stable order and reports the page" do
            %w[C A B].each { |letter| insert_rocbn_company(name: "PAGED #{letter}") }

            get PATH, params: { q: { company_name_cont: "paged" }, limit: 2, page: 2 }, headers: @headers

            assert_equal ["PAGED C"], listed("company_name")
            assert_equal({ "page" => 2, "pages" => 2, "count" => 3, "limit" => 2 }, response.parsed_body["meta"])
          end

          test "a search without a result is an empty list" do
            get PATH, params: { q: { company_name_cont: "no such company" } }, headers: @headers

            assert_response :ok
            assert_empty listed("company_name")
          end

          test "soft-deleted companies are never listed" do
            insert_rocbn_company(name: "GONE CO", deleted_at: Time.utc(2026, 1, 1))

            get PATH, params: { q: { company_name_cont: "gone" } }, headers: @headers

            assert_empty listed("company_name")
          end

          test "a request with nothing usable to search for is rejected, not answered with every company" do
            [{}, { q: { company_name_cont: "  " } }, { q: { bogus_cont: "x" } }, { q: { company_name_present: "1" } },
             { q: "company" }].each do |params|
              get PATH, params: params, headers: @headers

              assert_response :unprocessable_content, "expected #{params} to be rejected"
            end
          end

          test "the rejection explains what to enter" do
            get PATH, headers: @headers

            assert_equal({ "status" => "fail", "message" => "Enter a company name or a ROCBN number to search." },
                         response.parsed_body)
          end

          test "searching and fetching a company issue no write to the registry" do
            company = insert_rocbn_company(name: "READ ONLY CO")

            statements = capture_registry_sql do
              get PATH, params: { q: { company_name_cont: "read only" } }, headers: @headers
              get "#{PATH}/#{company.id}", headers: @headers
            end

            assert_not_empty statements
            assert_empty statements.grep(/\A\s*(INSERT|UPDATE|DELETE|REPLACE|CREATE|ALTER|DROP|TRUNCATE)/i)
          end

          test "a malformed search value is answered, never a server error" do
            get PATH, params: { q: { company_name_cont: { nested: "x" } } }, headers: @headers

            assert_response :ok
          end

          private

          def listed(key) = response.parsed_body["data"].pluck(key)
        end
      end
    end
  end
end
