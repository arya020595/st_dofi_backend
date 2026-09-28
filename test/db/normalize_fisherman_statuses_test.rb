require "test_helper"
require Rails.root.join("db/migrate/20260928100002_normalize_fisherman_statuses")

class NormalizeFishermanStatusesTest < ActiveSupport::TestCase
  test "clears fisherman_status on non-fisherman users" do
    officer = create(:user, :officer_shaped, role: create(:role, kind: Role::DOFI_OFFICER))
    jetty_manager = create(:user, :jetty_manager_shaped, role: create(:role, kind: Role::JETTY_MANAGER))
    [officer, jetty_manager].each { |user| stamp(user, "pending_approval") }

    run_migration

    assert_nil officer.reload.fisherman_status
    assert_nil jetty_manager.reload.fisherman_status
  end

  test "moves fishermen awaiting approval to claimable and leaves other fishermen alone" do
    pending = create(:user, :fins_governed_fisherman)
    stamp(pending, "pending_approval")
    suspended = create(:user, :fins_governed_fisherman)
    stamp(suspended, "suspended")

    run_migration

    assert_equal %w[claimable suspended], [pending.reload.fisherman_status, suspended.reload.fisherman_status]
  end

  private

  def stamp(user, fisherman_status)
    user.update_column(:fisherman_status, fisherman_status) # rubocop:disable Rails/SkipsModelValidations
  end

  def run_migration
    migration = NormalizeFishermanStatuses.new
    migration.suppress_messages { migration.up }
  end
end
