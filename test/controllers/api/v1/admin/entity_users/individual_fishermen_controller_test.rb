require "test_helper"

module Api
  module V1
    module Admin
      module EntityUsers
        class IndividualFishermenControllerTest < ActionDispatch::IntegrationTest
          setup do
            @password = "Password123!"
            @officer = create_officer
            @headers = auth_headers_for(@officer, password: @password)
            @full_time_profile = create(:company_profile, registration_type: "Small - Scale (Full-Time)")
            @commercial_profile = create(:company_profile, registration_type: "Commercial")
          end

          test "index returns individual fisherman users directly" do
            fisherman = create_fisherman(@full_time_profile, "Small - Scale (Full-Time)")
            create_fisherman(@commercial_profile, "Commercial")

            get "/api/v1/admin/entity_users/individual_fishermen",
                params: { registration_type: "Small - Scale (Full-Time),Small - Scale (Part-Time)" }, headers: @headers

            assert_response :ok
            data = response.parsed_body.fetch("data")

            assert_equal [fisherman.id], data.pluck("id")
            assert_equal [fisherman.name, "Small - Scale (Full-Time)"], data.first.values_at("name", "type")
          end

          private

          def create_officer
            permission = Permission.find_or_create_by!(code: "entity_users.list") do |record|
              record.name = record.code
            end
            role = create(:role, kind: Role::DOFI_OFFICER, permissions: [permission])
            create(:user, role:, position: "Administrator", unit: "HQ", password: @password,
                          password_confirmation: @password)
          end

          def create_fisherman(company_profile, registration_type)
            role = create(:role, :fisherman, company_profile:, name: "Owner", is_default: true)
            create(:user, role:, company_profile:, ic_number: next_ic_number, registration_type:)
          end

          def next_ic_number
            @ic_sequence = (@ic_sequence || 0) + 1
            format("51-%07d", @ic_sequence)
          end
        end
      end
    end
  end
end
