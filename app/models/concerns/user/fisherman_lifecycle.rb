module User::FishermanLifecycle
  extend ActiveSupport::Concern

  FISHERMAN_STATUSES = %w[pending_approval claimable active suspended revoked].freeze
  OWNER_SLOT_STATUSES = %w[pending_approval claimable active suspended].freeze

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

  def fisherman_owner_role_holder?
    role&.fisherman_owner_role? || false
  end
  alias has_fisherman_owner_role? fisherman_owner_role_holder?

  def occupies_fisherman_owner_slot?
    kept? && fisherman_owner_role_holder? && OWNER_SLOT_STATUSES.include?(fisherman_status)
  end

  def current_fisherman_owner?
    occupies_fisherman_owner_slot? && fisherman_status == "active"
  end

  def fins_governed_fisherman?
    kept? && fisherman? && dofi_company_profile_source? && system_managed_fisherman_role?
  end

  def fins_approval_required_fisherman?
    fins_governed_fisherman? && fisherman_status == "pending_approval"
  end

  private

  def dofi_company_profile_source?
    provisioning_source == ::Fisherman::ProvisionUser::DOFI_COMPANY_PROFILE
  end

  def system_managed_fisherman_role?
    role&.system_managed_fisherman_role? || false
  end

  def active_fisherman_identity_must_be_claimed
    return unless fisherman_status == "active"
    return if claimed_at.present? && brunei_id_verified_at.present?

    errors.add(:fisherman_status, "active requires claimed_at and brunei_id_verified_at")
  end
end
