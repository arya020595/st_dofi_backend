class BackfillNormalizedIcNumbersAndFishermanStatus < ActiveRecord::Migration[8.1]
  class MigrationUser < ActiveRecord::Base
    self.table_name = "users"
  end

  class MigrationRole < ActiveRecord::Base
    self.table_name = "roles"
  end

  FISHERMAN_PLATFORM = "fisherman".freeze
  FISHERMAN_STATUS_MAP = {
    "active" => "active",
    "pending" => "pending_approval",
    "rejected" => "revoked",
    "inactive" => "revoked",
    "suspended" => "suspended"
  }.freeze

  def up
    say_with_time "Backfilling normalized IC numbers for all users" do
      MigrationUser.where.not(ic_number: nil).find_each do |user|
        normalized = normalize_ic(user.ic_number)
        # rubocop:disable Rails/SkipsModelValidations
        user.update_columns(normalized_ic_number: normalized.presence)
        # rubocop:enable Rails/SkipsModelValidations
      end
    end

    say_with_time "Backfilling fisherman lifecycle fields" do
      fisherman_role_ids = MigrationRole.where(platform_scope: FISHERMAN_PLATFORM).select(:id)

      MigrationUser.where(role_id: fisherman_role_ids).find_each do |user|
        next if user.fisherman_status.present?

        fisherman_status = fisherman_status_for(user.status)
        claimed_at = fisherman_status == "active" ? user.brunei_id_verified_at : nil

        # rubocop:disable Rails/SkipsModelValidations
        user.update_columns(
          fisherman_status: fisherman_status,
          provisioning_source: user.provisioning_source || "dofi_company_profile",
          claimed_at: claimed_at
        )
        # rubocop:enable Rails/SkipsModelValidations
      end
    end
  end

  def down
    # rubocop:disable Rails/SkipsModelValidations
    MigrationUser.update_all(
      normalized_ic_number: nil,
      fisherman_status: nil,
      provisioning_source: nil,
      claimed_at: nil
    )
    # rubocop:enable Rails/SkipsModelValidations
  end

  private

  def normalize_ic(value)
    value.to_s.gsub(/[^a-zA-Z0-9]/, "").upcase
  end

  def fisherman_status_for(status)
    FISHERMAN_STATUS_MAP.fetch(status, "pending_approval")
  end
end
