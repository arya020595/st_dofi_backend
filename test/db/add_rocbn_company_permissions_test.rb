require "test_helper"
require Rails.root.join("db/migrate/20261023100000_add_rocbn_company_permissions")

class AddRocbnCompanyPermissionsTest < ActiveSupport::TestCase
  CODES = %w[rocbn_companies.list rocbn_companies.view].freeze

  test "creates both rows with the metadata the catalog computes" do
    run_migration

    CODES.each do |code|
      entry = Permission::Catalog.fetch(code)

      assert_equal [entry[:name], "dofi_officer", "profiling", entry[:section_order], entry[:resource_order]],
                   Permission.find_by!(code: code).attributes.values_at("name", "platform_scope", "section",
                                                                        "section_order", "resource_order")
    end
  end

  test "grants every officer role that can create a profile, and the DoFi Officer role" do
    creator = create(:role, permissions: [create(:permission, code: "company_profiles.create")])
    officer = create(:role, kind: Role::DOFI_OFFICER)

    run_migration

    assert_equal CODES, creator.reload.permissions.pluck(:code).grep(/\Arocbn_companies/).sort
    assert_equal CODES, officer.reload.permissions.pluck(:code).sort
  end

  test "does not grant roles that cannot create a profile, or fisherman roles" do
    reader = create(:role, permissions: [create(:permission, code: "company_profiles.view")])
    fisherman = create(:role, :fisherman, permissions: [create(:permission, code: "company_profiles.create")])

    run_migration

    assert_empty reader.reload.permissions.pluck(:code).grep(/\Arocbn_companies/)
    assert_empty fisherman.reload.permissions.pluck(:code).grep(/\Arocbn_companies/)
  end

  test "is idempotent" do
    creator = create(:role, permissions: [create(:permission, code: "company_profiles.create")])

    run_migration
    run_migration

    assert_equal 1, Permission.where(code: "rocbn_companies.list").count
    assert_equal 2, creator.reload.permissions.where("code LIKE ?", "rocbn_companies.%").count
  end

  test "down removes the rows and every grant" do
    creator = create(:role, permissions: [create(:permission, code: "company_profiles.create")])
    migration = AddRocbnCompanyPermissions.new

    migration.suppress_messages do
      migration.up
      migration.down
    end

    assert_not Permission.exists?(["code LIKE ?", "rocbn_companies.%"])
    assert_equal ["company_profiles.create"], creator.reload.permissions.pluck(:code)
  end

  private

  def run_migration
    migration = AddRocbnCompanyPermissions.new
    migration.suppress_messages { migration.up }
  end
end
