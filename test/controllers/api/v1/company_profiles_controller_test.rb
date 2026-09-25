require "test_helper"

module Api
  module V1
    # rubocop:disable Minitest/MultipleAssertions
    class CompanyProfilesControllerTest < ActionDispatch::IntegrationTest
      setup do
        @password = "Password123!"

        admin_permissions = %w[list view create update delete].map do |action|
          Permission.find_or_create_by!(code: "company_profiles.#{action}") do |permission|
            permission.name = "Profiling - #{action.capitalize}"
          end
        end
        @admin_role = create(:role, kind: Role::DOFI_OFFICER, permissions: admin_permissions)
        @no_access_role = create(:role, kind: Role::JETTY_MANAGER)

        @admin = create(:user, :officer_shaped, role: @admin_role,
                                                password: @password, password_confirmation: @password)
        @plain_user = create(:user, :jetty_manager_shaped, role: @no_access_role,
                                                           password: @password, password_confirmation: @password)
        @target = create(:company_profile)

        @admin_headers = auth_headers_for(@admin, password: @password)
        @plain_headers = auth_headers_for(@plain_user, password: @password)
      end

      def valid_params(overrides = {})
        {
          company_profile: {
            registration_type: "Small-Scale (Company)", company_name: "New Profiling Co",
            company_address: "Spg 1, Test", mailing_address: "P.O. Box 1, Serasa", rocbn_no: "RC-NEW-001",
            contact_no: "71222222",
            district: "Brunei - Muara", mukim: "Serasa", village: "Kapok",
            fisherman_card_no: "R-2026-000999", issue_date: "2026-01-01", license_expiry_date: "2026-12-31",
            owner: { full_name: "Owner Person", gender: "Male", ic_no: "01-700010", ic_colour: "Yellow" }
          }.merge(overrides)
        }
      end

      test "index requires the list/view permission" do
        get "/api/v1/admin/company_profiles", headers: @plain_headers

        assert_response :forbidden

        get "/api/v1/admin/company_profiles", headers: @admin_headers

        assert_response :ok
      end

      test "index filters by company_name via ransack" do
        create(:company_profile, company_name: "Findable Fish Co", rocbn_no: "RC-FINDABLE")

        get "/api/v1/admin/company_profiles", params: { q: { company_name_cont: "Findable" } }, headers: @admin_headers

        assert_response :ok
        assert_equal ["Findable Fish Co"], response.parsed_body["data"].pluck("company_name")
      end

      test "index returns one entry per company, nesting the admin profile under the owner" do
        company_profile = create(:company_profile, company_name: "Two Person Co", rocbn_no: "RC-TWO-PERSON")
        create(:company_profile_contact, company_profile: company_profile, designation: "Owner")
        create(:company_profile_contact, company_profile: company_profile, designation: "Admin",
                                         full_name: "Admin Person")

        get "/api/v1/admin/company_profiles", params: { q: { rocbn_no_eq: "RC-TWO-PERSON" } }, headers: @admin_headers

        assert_response :ok
        data = response.parsed_body["data"]

        assert_equal [company_profile.id], data.pluck("id")
        assert_equal "Admin Person", data.first.dig("admin_profile", "full_name")
      end

      test "index omits the admin profile when the company has no admin" do
        company_profile = create(:company_profile, company_name: "Solo Co", rocbn_no: "RC-SOLO")
        create(:company_profile_contact, company_profile: company_profile, designation: "Owner")

        get "/api/v1/admin/company_profiles", params: { q: { rocbn_no_eq: "RC-SOLO" } }, headers: @admin_headers

        assert_response :ok
        assert_nil response.parsed_body["data"].first["admin_profile"]
      end

      test "create with only an owner persists one company profile, one contact, and one pending user" do
        assert_difference({ "CompanyProfile.count" => 1, "CompanyProfileContact.count" => 1, "User.count" => 1 }) do
          post "/api/v1/admin/company_profiles", params: valid_params, headers: @admin_headers, as: :json
        end

        data = response.parsed_body["data"]

        assert_equal "Owner Person", data.dig("owner_profile", "full_name")
        assert_match(/\ADOF-\d{4,}\z/, data.dig("company_profile", "profile_number"))
        assert_equal "P.O. Box 1, Serasa", data.dig("company_profile", "mailing_address")
        assert_nil data["admin_profile"]
        assert_equal "active", data.dig("owner_user", "status")
      end

      test "create with both owner and admin persists one company profile, two contacts, and two pending users" do
        params = valid_params(admin: { full_name: "Admin Person", gender: "Female", ic_no: "01-700011",
                                       ic_colour: "Green" })

        assert_difference({ "CompanyProfile.count" => 1, "CompanyProfileContact.count" => 2, "User.count" => 2 }) do
          post "/api/v1/admin/company_profiles", params: params, headers: @admin_headers, as: :json
        end

        data = response.parsed_body["data"]

        assert_equal "Admin Person", data.dig("admin_profile", "full_name")
        assert_equal data.dig("company_profile", "id"), data.dig("owner_profile", "company_profile_id")
        assert_equal "active", data.dig("admin_user", "status")
      end

      test "create without permission is forbidden" do
        post "/api/v1/admin/company_profiles", params: valid_params, headers: @plain_headers, as: :json

        assert_response :forbidden
      end

      test "create with a missing required field rolls back and returns errors" do
        assert_no_difference(["CompanyProfile.count", "CompanyProfileContact.count", "User.count"]) do
          post "/api/v1/admin/company_profiles", params: valid_params(company_name: ""), headers: @admin_headers,
                                                 as: :json
        end

        assert_response :unprocessable_content
        assert_predicate response.parsed_body["errors"], :present?
      end

      test "update ignores a client supplied worker quota" do
        original_quota = @target.worker_quota

        patch "/api/v1/admin/company_profiles/#{@target.id}", params: { company_profile: { worker_quota: 99 } },
                                                              headers: @admin_headers, as: :json

        assert_response :ok
        assert_equal original_quota, @target.reload.worker_quota
      end

      test "update replaces a claimed owner/admin contact and user, revoking the old identity" do
        owner = create(
          :company_profile_contact,
          company_profile: @target,
          designation: "Owner",
          full_name: "Old Owner",
          ic_no: "01-701001"
        )
        admin = create(
          :company_profile_contact,
          company_profile: @target,
          designation: "Admin",
          full_name: "Old Admin",
          ic_no: "01-701002"
        )
        owner_user = provisioned_contact_user(owner, is_default: true)
        admin_user = provisioned_contact_user(admin, is_default_admin: true)
        activate_claimed_user(owner_user)
        activate_claimed_user(admin_user)

        assert_difference({ "CompanyProfileContact.count" => 2, "User.count" => 2 }) do
          patch "/api/v1/admin/company_profiles/#{@target.id}",
                params: profile_update_params,
                headers: @admin_headers,
                as: :json
        end

        assert_response :ok

        assert_predicate owner.reload, :discarded?
        assert_equal "Old Owner", owner.full_name
        assert_equal "inactive", owner_user.reload.fisherman_status

        new_owner = @target.owner_contact
        new_owner_user = new_owner.users.kept.first

        assert_equal "Updated Owner", new_owner.full_name
        assert_equal "Updated Owner", new_owner_user.name
        assert_equal "01-701101", new_owner_user.ic_number
        assert_predicate new_owner_user.claimed_at, :present?

        assert_predicate admin.reload, :discarded?
        assert_equal "inactive", admin_user.reload.fisherman_status

        new_admin = @target.admin_contact
        new_admin_user = new_admin.users.kept.first

        assert_equal "Updated Admin", new_admin.full_name
        assert_equal "Updated Admin", new_admin_user.name
        assert_equal "01-701102", new_admin_user.ic_number
        assert_predicate new_admin_user.claimed_at, :present?
      end

      test "update renames an existing not-yet-claimed owner contact and user in place" do
        owner = create(
          :company_profile_contact,
          company_profile: @target,
          designation: "Owner",
          full_name: "Old Owner",
          ic_no: "01-701301"
        )
        owner_user = provisioned_contact_user(owner, is_default: true)
        owner_user.update!(claimed_at: nil, brunei_id_verified_at: nil)

        assert_no_difference(["CompanyProfileContact.count", "User.count"]) do
          patch "/api/v1/admin/company_profiles/#{@target.id}",
                params: { company_profile: { owner: owner_update_params } },
                headers: @admin_headers,
                as: :json
        end

        assert_response :ok
        assert_equal "Updated Owner", owner.reload.full_name
        assert_equal "Updated Owner", owner_user.reload.name
        assert_equal "01-701101", owner_user.ic_number
        assert_nil owner_user.claimed_at
      end

      test "update provisions a missing user for an existing owner contact" do
        owner = create(
          :company_profile_contact,
          company_profile: @target,
          designation: "Owner",
          full_name: "Old Owner",
          ic_no: "01-701201"
        )

        assert_difference("User.count", 1) do
          patch "/api/v1/admin/company_profiles/#{@target.id}",
                params: { company_profile: { owner: owner_update_params } },
                headers: @admin_headers,
                as: :json
        end

        assert_response :ok
        user = owner.users.kept.first

        assert_equal "Updated Owner", owner.reload.full_name
        assert_equal "Updated Owner", user.name
        assert_equal "01-701101", user.ic_number
      end

      test "destroy soft-deletes the target profile and its kept contacts" do
        contact = create(:company_profile_contact, company_profile: @target, designation: "Owner")

        delete "/api/v1/admin/company_profiles/#{@target.id}", headers: @admin_headers

        assert_response :ok
        assert_predicate @target.reload, :discarded?
        assert_predicate contact.reload, :discarded?
      end

      private

      def provisioned_contact_user(contact, is_default: false, is_default_admin: false)
        role = provisioned_contact_role(is_default, is_default_admin)
        create(:user, role:, company_profile: @target, company_profile_contact: contact, name: contact.full_name,
                      ic_number: contact.ic_no, registration_type: @target.registration_type,
                      fisherman_status: "active", claimed_at: Time.current, brunei_id_verified_at: Time.current,
                      provisioning_source: ::Fisherman::ProvisionUser::DOFI_COMPANY_PROFILE)
      end

      def provisioned_contact_role(is_default, is_default_admin)
        create(:role, :fisherman, company_profile: @target, name: (is_default ? "Owner" : "Admin"), is_default:,
                                  is_default_admin:)
      end

      def profile_update_params
        {
          company_profile: {
            company_name: "Updated Profiling Co",
            owner: { full_name: "Updated Owner", gender: "Male", ic_no: "01-701101", ic_colour: "Yellow" },
            admin: { full_name: "Updated Admin", gender: "Female", ic_no: "01-701102", ic_colour: "Green" }
          }
        }
      end

      def owner_update_params
        { full_name: "Updated Owner", gender: "Male", ic_no: "01-701101", ic_colour: "Yellow" }
      end

      def activate_claimed_user(user)
        user.update!(fisherman_status: "active", claimed_at: Time.current, brunei_id_verified_at: Time.current)
      end
    end
    # rubocop:enable Minitest/MultipleAssertions
  end
end
