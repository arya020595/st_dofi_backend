class AddEntityUserCountToCompanyProfiles < ActiveRecord::Migration[8.1]
  def up
    add_column :company_profiles, :entity_user_count, :integer, null: false, default: 0
    backfill_entity_user_counts
  end

  def down
    remove_column :company_profiles, :entity_user_count
  end

  private

  def backfill_entity_user_counts
    safety_assured do
      execute <<~SQL.squish
        UPDATE company_profiles
        SET entity_user_count = (
          SELECT COUNT(*) FROM users
          WHERE users.company_profile_id = company_profiles.id AND users.discarded_at IS NULL
        )
      SQL
    end
  end
end
