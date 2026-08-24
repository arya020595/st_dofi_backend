require "test_helper"

module Fisherman
  class ProvisionUserTest < ActiveSupport::TestCase
    include Dry::Monads[:result]

    setup do
      @actor = create(:user)
      @company_profile = create(:company_profile)
    end

    test "source A derives pending approval status and Owner role from contact" do
      contact = create(:company_profile_contact, company_profile: @company_profile, designation: "Owner",
                                                 ic_no: "01-111111")

      result = ProvisionUser.call(company_profile: @company_profile,
                                  provisioning_source: ProvisionUser::DOFI_COMPANY_PROFILE,
                                  created_by: @actor,
                                  name: "Ignored",
                                  ic_number: "99-999999",
                                  company_profile_contact: contact)

      user = result.value!

      assert_equal "pending_approval", user.fisherman_status
      assert_equal ["Muhammad Shahrizan Bin Haji Said", "01-111111", "01111111"],
                   [user.name, user.ic_number, user.normalized_ic_number]
      assert_equal [contact, "Owner", @company_profile],
                   [user.company_profile_contact, user.role.name, user.company_profile]
    end

    test "source B derives claimable status and validates role company" do
      role = create(:role, :fisherman, company_profile: @company_profile)

      result = ProvisionUser.call(company_profile: @company_profile,
                                  provisioning_source: ProvisionUser::FISHERMAN_OWNER,
                                  created_by: @actor,
                                  name: "Teammate",
                                  ic_number: "01-222222",
                                  role: role)

      user = result.value!

      assert_equal "claimable", user.fisherman_status
      assert_equal role, user.role
    end

    test "source B rejects a role from another company" do
      other_role = create(:role, :fisherman)

      result = ProvisionUser.call(company_profile: @company_profile,
                                  provisioning_source: ProvisionUser::FISHERMAN_OWNER,
                                  created_by: @actor,
                                  name: "Teammate",
                                  ic_number: "01-333333",
                                  role: other_role)

      assert_equal :role_company_mismatch, result.failure
    end

    test "global normalized ic conflict crosses audiences" do
      jetty_role = create(:role, kind: Role::JETTY_MANAGER, name: "Jetty Manager")
      create(:user, :jetty_manager_shaped, role: jetty_role, ic_number: "01-444444")
      role = create(:role, :fisherman, company_profile: @company_profile)

      result = ProvisionUser.call(company_profile: @company_profile,
                                  provisioning_source: ProvisionUser::FISHERMAN_OWNER,
                                  created_by: @actor,
                                  name: "Teammate",
                                  ic_number: "01444444",
                                  role: role)

      assert_equal :ic_conflict_other_company, result.failure
    end

    test "unique index race is converted into deterministic domain conflict" do
      role = create(:role, :fisherman, company_profile: @company_profile)
      availability = race_availability_sequence

      with_singleton_stub(CheckIcAvailability, :call, ->(**) { availability.call }) do
        with_singleton_stub(User, :new, ->(*) { raise ActiveRecord::RecordNotUnique }) do
          result = provision_owner_teammate(role)

          assert_equal :ic_conflict_same_company, result.failure
        end
      end
    end

    private

    def with_singleton_stub(target, method_name, callable)
      singleton = target.singleton_class
      original = target.method(method_name)
      singleton.define_method(method_name, callable)
      yield
    ensure
      singleton.define_method(method_name) { |*args, **kwargs| original.call(*args, **kwargs) }
    end

    def race_availability_sequence
      calls = 0
      lambda do
        calls += 1
        calls == 1 ? Success(status: :available) : Success(status: :existing_same_company)
      end
    end

    def provision_owner_teammate(role)
      ProvisionUser.call(company_profile: @company_profile,
                         provisioning_source: ProvisionUser::FISHERMAN_OWNER,
                         created_by: @actor,
                         name: "Teammate",
                         ic_number: "01-555000",
                         role: role)
    end
  end
end
