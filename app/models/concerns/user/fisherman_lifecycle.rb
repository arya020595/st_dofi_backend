module User::FishermanLifecycle
  extend ActiveSupport::Concern

  FISHERMAN_STATUSES = %w[active inactive].freeze
  OWNER_SLOT_STATUSES = %w[active].freeze

  included do
    aasm(:fisherman, column: :fisherman_status, namespace: :fisherman) do
      state :active
      state :inactive

      event(:deactivate_fisherman) { transitions from: :active, to: :inactive }
      event(:reactivate_fisherman) { transitions from: :inactive, to: :active }
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

  private

  def active_fisherman_identity_must_be_claimed
    return unless fisherman? && fisherman_status == "active"
    return if claimed_at.present? && brunei_id_verified_at.present?

    errors.add(:fisherman_status, "active requires claimed_at and brunei_id_verified_at")
  end
end
