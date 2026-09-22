class CreateCompanyProfiles < ActiveRecord::Migration[8.1]
  def up
    create_table :company_profiles, id: :uuid do |t|
      t.string :reference_id, null: false # REG-DOF-001 (auto-generated, shown in list)
      t.string :profile_number, null: false # DOF-0001 (database-generated profile number)
      t.string :dofi_registration_no # DOF-2026-001 (official DoFi reg no., shown in detail)
      t.string :registration_type, null: false # "Commercial", "Individual (Part - Time)", "Small - Scale (Full-Time)"

      # Company / Business fields (for Commercial type)
      t.string :company_name
      t.text :company_address
      t.string :rocbn_no # Auto-filled from company search (e.g. RC1234567890)
      t.string :contact_no

      # Individual / Owner fields
      t.string :full_name # Person's full name (owner / fisherman)
      t.string :ic_no # IC No. (e.g. xx-xxxxxx)
      t.string :ic_colour # IC Colour (dropdown)
      t.string :gender # "Male", "Female"

      # Location
      t.string :district
      t.string :mukim
      t.string :village
      t.string :full_address # For Individual type

      # Fisherman Card
      t.string :fisherman_card_no # BN-002-302
      t.date :issue_date
      t.date :license_expiry_date # "Fisherman Card Expiry Date" / "License Expiry Date"
      t.string :designation # e.g. "Fisherman", "Boat Owner"

      # Profile status
      t.integer :worker_quota, null: false, default: 0
      t.date :date_approval
      t.string :approval_status, null: false, default: "pending"
      # AASM: pending, approved, amendment_required
      t.text :amendment_remarks
      # NOTE: FK to :users is added in a later migration (AddForeignKeyApprovedByToCompanyProfiles)
      # because the users table does not exist yet at this point in migration order.
      t.uuid :approved_by
      t.datetime :approved_at
      t.string :logo_url # ActiveStorage or URL
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :company_profiles, :reference_id, unique: true
    add_index :company_profiles, :profile_number, unique: true
    add_index :company_profiles, :rocbn_no
    add_index :company_profiles, :ic_no
    add_index :company_profiles, :approval_status
    add_index :company_profiles, :approved_by
    add_index :company_profiles, :discarded_at

    create_profile_number_generator
  end

  def down
    drop_profile_number_generator
    drop_table :company_profiles
  end

  private

  def create_profile_number_generator
    safety_assured do
      execute <<~SQL.squish
        CREATE SEQUENCE company_profile_number_sequence START WITH 1 INCREMENT BY 1 NO CYCLE;

        CREATE FUNCTION assign_company_profile_number()
        RETURNS trigger
        LANGUAGE plpgsql
        AS $$
        BEGIN
          NEW.profile_number := format(
            'DOF-%s',
            lpad(nextval('company_profile_number_sequence')::text, 4, '0')
          );
          RETURN NEW;
        END;
        $$;

        CREATE TRIGGER set_company_profile_number_before_insert
        BEFORE INSERT ON company_profiles
        FOR EACH ROW
        EXECUTE FUNCTION assign_company_profile_number();
      SQL
    end
  end

  def drop_profile_number_generator
    safety_assured do
      execute <<~SQL.squish
        DROP TRIGGER IF EXISTS set_company_profile_number_before_insert ON company_profiles;
        DROP FUNCTION IF EXISTS assign_company_profile_number();
        DROP SEQUENCE IF EXISTS company_profile_number_sequence;
      SQL
    end
  end
end
