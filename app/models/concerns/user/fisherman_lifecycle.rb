module User::FishermanLifecycle
  extend ActiveSupport::Concern

  FISHERMAN_STATUSES = %w[pending_approval claimable active suspended revoked].freeze

  included do
    aasm(:fisherman, column: :fisherman_status, namespace: :fisherman) do
      state :pending_approval
      state :claimable
      state :active
      state :suspended
      state :revoked

      event(:approve_fisherman) { transitions from: :pending_approval, to: :claimable }
      event(:reject_fisherman) { transitions from: :pending_approval, to: :revoked }
      event(:reset_approval_fisherman) { transitions from: :claimable, to: :pending_approval }
      event(:claim_fisherman) { transitions from: :claimable, to: :active }
      event(:suspend_fisherman) { transitions from: :active, to: :suspended }
      event(:reactivate_fisherman) { transitions from: :suspended, to: :active }
      event(:revoke_fisherman) { transitions from: %i[pending_approval claimable active suspended], to: :revoked }
    end

    validates :fisherman_status, inclusion: { in: FISHERMAN_STATUSES }, allow_nil: true
    validate :active_fisherman_identity_must_be_claimed
  end

  private

  def active_fisherman_identity_must_be_claimed
    return unless fisherman_status == "active"
    return if claimed_at.present? && brunei_id_verified_at.present?

    errors.add(:fisherman_status, "active requires claimed_at and brunei_id_verified_at")
  end
end
