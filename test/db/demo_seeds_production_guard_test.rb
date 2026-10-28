require "test_helper"

# db/seeds.rb loads demo data (Fisherman and Jetty Manager users with the known default password) everywhere except
# production. These load the real seed files, so they take a few seconds.
class DemoSeedsProductionGuardTest < ActiveSupport::TestCase
  include DirectoryTestSupport

  KNOWN_DEFAULT = "ChangeMe123!".freeze

  def run_seeds(config, **env)
    with_directory_config(config) do
      with_env({ "ADMIN_AD_USERNAME" => "mprt/real.admin" }.merge(env)) do
        capture_io { load Rails.root.join("db/seeds.rb") }
      end
    end
  end

  def known_default_accounts
    User.where.not(encrypted_password: "").select do |user|
      BCrypt::Password.new(user.encrypted_password).is_password?(KNOWN_DEFAULT)
    end
  end

  # ADMIN_DEFAULT_PASSWORD is the variable that used to give the demo accounts their password: even set, it must not
  # bring them back on production.
  test "production seeds only reference data: no demo users, companies or manifests, whatever the password variable" do
    run_seeds(production_directory_config, "ADMIN_DEFAULT_PASSWORD" => KNOWN_DEFAULT)

    demo_rows = [CompanyProfile.count, CompanyProfileContact.count, CompaniesVessel.count, Manifest.count]

    assert_equal [["admin@dofi.gov.bn"], [0, 0, 0, 0], []], [User.pluck(:email), demo_rows, known_default_accounts]
    assert_equal [true, true], [Role.exists?(kind: Role::DOFI_OFFICER), Permission.exists?]
  end

  test "outside production the demo seeds still create the demo Fisherman and Jetty Manager users" do
    run_seeds(staging_directory_config, "ADMIN_DEFAULT_PASSWORD" => nil)

    demo_users = User.joins(:role).where(roles: { platform_scope: Role::FISHERMAN_PLATFORM })
    jetty_managers = User.joins(:role).where(roles: { kind: Role::JETTY_MANAGER })

    assert_equal [true, true, true, false],
                 [CompanyProfile.exists?, demo_users.exists?, jetty_managers.exists?, known_default_accounts.empty?]
  end
end
