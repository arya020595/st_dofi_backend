require "test_helper"

module Api
  module V1
    module Approvals
      class FishermenDetailTest < ActionDispatch::IntegrationTest
        setup do
          @password = "Password123!"
          permissions = find_or_create_permissions(%w[fisherman_approvals.view])
          role = create(:role, kind: Role::DOFI_OFFICER, permissions: permissions)
          admin = create(:user, :officer_shaped, role: role, password: @password,
                                                 password_confirmation: @password)
          @headers = auth_headers_for(admin, password: @password)
        end

        test "show returns merged owner and admin company profile" do
          profile = create(:company_profile, rocbn_no: "RC-SHARED")
          owner_contact = create(:company_profile_contact, company_profile: profile, ic_no: "01-840001",
                                                           designation: "Owner")
          admin_contact = create(:company_profile_contact, company_profile: profile, ic_no: "01-840002",
                                                           designation: "Admin")
          owner = create_owner(profile, owner_contact)

          get "/api/v1/admin/approvals/fishermen/#{owner.id}", headers: @headers

          assert_response :ok
          assert_equal expected_payload(profile, owner_contact, admin_contact), actual_payload
        end

        private

        def create_owner(profile, contact)
          role = create(:role, :fisherman, name: "Owner", company_profile: profile, is_default: true)
          create(:user, role: role, status: "active", fisherman_status: "pending_approval",
                        ic_number: contact.ic_no, registration_type: "Commercial", designation: "Owner",
                        provisioning_source: Fisherman::ProvisionUser::DOFI_COMPANY_PROFILE,
                        company_profile: profile, company_profile_contact: contact)
        end

        def actual_payload
          data = response.parsed_body["data"]
          [
            data.dig("company_profile", "id"),
            data.dig("company_profile", "company_name"),
            data.dig("company_profile", "rocbn_no"),
            data.dig("owner_profile", "full_name"),
            data.dig("admin_profile", "full_name")
          ]
        end

        def expected_payload(profile, owner_contact, admin_contact)
          [profile.id, profile.company_name, profile.rocbn_no, owner_contact.full_name, admin_contact.full_name]
        end
      end
    end
  end
end
