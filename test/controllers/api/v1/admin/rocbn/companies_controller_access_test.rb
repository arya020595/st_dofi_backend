require "test_helper"

module Api
  module V1
    module Admin
      module Rocbn
        # None of these needs the registry: the request is turned away before it, or the registry is made to fail.
        class CompaniesControllerAccessTest < ActionDispatch::IntegrationTest
          PATH = "/api/v1/admin/rocbn/companies".freeze
          PASSWORD = "Password123!".freeze
          SEARCH = { q: { company_name_cont: "amiirul" } }.freeze

          test "a request without a token is unauthorized" do
            get PATH, params: SEARCH

            assert_response :unauthorized
          end

          test "the list permission is required" do
            get PATH, params: SEARCH, headers: headers_for(create(:role))

            assert_response :forbidden
          end

          test "a fisherman is turned away by the admin audience" do
            fisherman = create(:role, :fisherman)

            get PATH, params: SEARCH, headers: headers_for(fisherman, ic_number: SecureRandom.hex(5),
                                                                      registration_type: "Commercial")

            assert_response :forbidden
          end

          test "an unreachable registry is a 503 with a safe message, and the rest of the API keeps working" do
            headers = officer_headers_for(permission_codes: %w[rocbn_companies.list])

            with_unreachable_registry do
              get PATH, params: SEARCH, headers: headers

              assert_response :service_unavailable
              assert_equal({ "status" => "fail", "message" => I18n.t("errors.rocbn_unavailable") },
                           response.parsed_body)
            end

            get "/api/v1/permissions", headers: headers

            assert_response :ok
          end

          private

          def headers_for(role, **user_attributes)
            user = create(:user, role: role, password: PASSWORD, password_confirmation: PASSWORD, **user_attributes)
            auth_headers_for(user, password: PASSWORD)
          end

          # The registry failing the way a down or slow server does: the adapter's connection error.
          def with_unreachable_registry
            singleton = ::Rocbn::Company.singleton_class
            original = ::Rocbn::Company.method(:kept)
            singleton.define_method(:kept) { |*| raise ActiveRecord::ConnectionNotEstablished, "no route to host" }
            yield
          ensure
            singleton.define_method(:kept, original)
          end
        end
      end
    end
  end
end
