class BackfillCompanyProfileContacts < ActiveRecord::Migration[8.1]
  FK_TABLES = %w[companies_captains companies_crews companies_fishing_gears companies_vessels manifests].freeze

  # `down` only undiscards CompanyProfile rows this migration itself discarded. Rows already
  # discarded before this migration ran (deliberately left untouched by `up`) must never be
  # undiscarded, so we only touch discards at-or-after this migration's own timestamp.
  BACKFILL_STARTED_AT = Time.zone.parse("2026-07-12 10:08:00").freeze

  def up
    ActiveRecord::Base.transaction do
      merged_groups(CompanyProfile.kept.order(:created_at).to_a).each { |group| merge_group(group) }
    end
  end

  def down
    ActiveRecord::Base.transaction do
      # rubocop:disable Rails/SkipsModelValidations -- reversing a bulk FK repoint; nothing here needs validation
      User.where.not(company_profile_contact_id: nil).update_all(company_profile_contact_id: nil)
      # rubocop:enable Rails/SkipsModelValidations
      CompanyProfileContact.delete_all
      CompanyProfile.where(discarded_at: BACKFILL_STARTED_AT..).find_each(&:undiscard)
    end
  end

  private

  # Rows created in the same POST /api/v1/company_profiles call share one dofi_registration_no
  # (always present, immutable post-creation) — a reliable "submitted together" grouping key.
  # Blank dofi_registration_no rows (e.g. hand-built test/manual data) are never grouped with
  # each other, only ever singleton groups, to avoid falsely pairing unrelated rows.
  def inner_groups(profiles)
    blank, present = profiles.partition { |profile| profile.dofi_registration_no.blank? }
    present.group_by(&:dofi_registration_no).values + blank.map { |profile| [profile] }
  end

  # Recovers "an Admin was added to an existing company via a later, separate submission" by
  # merging inner-groups that share the same non-blank rocbn_no + company_name — the FE's
  # "Select & Search Company" step auto-fills both identically from the selected company.
  def merged_groups(profiles)
    key_to_index = {}

    inner_groups(profiles).each_with_object([]) do |group, merged|
      key = merge_key(group)

      if key && key_to_index.key?(key)
        merged[key_to_index[key]].concat(group)
      else
        merged << group
        key_to_index[key] = merged.size - 1 if key
      end
    end
  end

  def merge_key(group)
    representative = group.first
    return nil if representative.rocbn_no.blank? || representative.company_name.blank?

    [representative.rocbn_no, representative.company_name]
  end

  def merge_group(group)
    survivor = survivor_for(group)
    contact_by_row_id = group.index_by(&:id).transform_values { |profile| create_contact!(profile, survivor) }
    loser_ids = group.map(&:id) - [survivor.id]

    relink_users!(group.map(&:id), survivor, contact_by_row_id)
    relink_fk_tables!(loser_ids, survivor.id)
    CompanyProfile.where(id: loser_ids).find_each(&:discard)
  end

  def survivor_for(group)
    owners = group.select { |profile| profile.designation == "Owner" }.sort_by(&:created_at)
    owners.first || group.min_by(&:created_at)
  end

  def create_contact!(profile, survivor)
    CompanyProfileContact.create!(
      company_profile_id: survivor.id, full_name: profile.full_name, ic_no: profile.ic_no,
      ic_colour: profile.ic_colour, gender: profile.gender, designation: profile.designation,
      created_at: profile.created_at, updated_at: profile.updated_at
    )
  end

  # rubocop:disable Rails/SkipsModelValidations -- pure FK repoint on already-valid, already-persisted
  # rows; running full validations here would risk spurious failures from unrelated attributes.
  def relink_users!(group_ids, survivor, contact_by_row_id)
    User.where(company_profile_id: group_ids).find_each do |user|
      contact = contact_by_row_id.fetch(user.company_profile_id)
      user.update_columns(company_profile_id: survivor.id, company_profile_contact_id: contact.id)
    end
  end

  def relink_fk_tables!(loser_ids, survivor_id)
    return if loser_ids.empty?

    FK_TABLES.each do |table_name|
      Class.new(ActiveRecord::Base) { self.table_name = table_name }
           .where(company_profile_id: loser_ids)
           .update_all(company_profile_id: survivor_id)
    end
  end
  # rubocop:enable Rails/SkipsModelValidations
end
