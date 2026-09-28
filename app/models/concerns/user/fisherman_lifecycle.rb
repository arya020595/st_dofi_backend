module User::FishermanLifecycle
  extend ActiveSupport::Concern

  FISHERMAN_STATUSES = %w[claimable active suspended revoked].freeze
  OWNER_SLOT_STATUSES = %w[claimable active suspended].freeze

  included do
    aasm(:fisherman, column: :fisherman_status, namespace: :fisherman) do
      state :claimable
      state :active
      state :suspended
      state :revoked

      event(:claim_fisherman) { transitions from: :claimable, to: :active }
      event(:suspend_fisherman) { transitions from: :active, to: :suspended }
      event(:reactivate_fisherman) { transitions from: :suspended, to: :active }
      event(:revoke_fisherman) { transitions from: %i[claimable active suspended], to: :revoked }
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
