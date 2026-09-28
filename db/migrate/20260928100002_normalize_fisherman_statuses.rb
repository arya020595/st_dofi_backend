# `pending_approval` no longer exists (FINS Approval was removed), and User no longer lets AASM stamp a
# fisherman_status onto non-fisherman users. Rows written before that still carry one: every DoFi Officer
# and Jetty Manager got the old initial state, `pending_approval`, which now fails validation on the next
# save (deactivate, locale change, ...). Clear it for non-fisherman users and move provisioned fishermen
# that were still awaiting approval to `claimable`, where Company Profiling provisioning now starts them.
class NormalizeFishermanStatuses < ActiveRecord::Migration[8.1]
  def up
    safety_assured do
      execute <<~SQL.squish
        UPDATE users SET fisherman_status = NULL
        WHERE fisherman_status IS NOT NULL
          AND (role_id IS NULL OR role_id NOT IN (SELECT id FROM roles WHERE platform_scope = 'fisherman'))
      SQL
      execute "UPDATE users SET fisherman_status = 'claimable' WHERE fisherman_status = 'pending_approval'"
    end
  end

  # Nothing to restore: the cleared values were never meaningful, and pending_approval no longer exists.
  def down; end
end
