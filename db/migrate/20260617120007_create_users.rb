class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :uuid do |t|
      # Devise columns
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at

      # Profile
      t.string :employee_id # Auto-generated: DOFI-001 (readonly, shown in User Account page)
      t.string :name, null: false
      t.string :ic_number
      t.string :unit
      t.string :position
      t.string :status, null: false, default: "active" # enum: active, inactive, suspended
      t.string :username_directory # AD username (for future SSO)
      t.string :doft_registration_no
      t.string :registration_type

      # Bilingual API response preference (Layer 2 of the multilingual strategy).
      # Mobility / per-record translated columns (Layer 3) are intentionally skipped for now.
      t.string :preferred_locale, null: false, default: "en"

      # BruneiID national digital identity verification (Section 22)
      t.datetime :brunei_id_verified_at

      # Relations
      t.references :role, type: :uuid, foreign_key: true
      t.references :company_profile, type: :uuid, foreign_key: true

      # JWT token revocation (JTI matcher)
      t.string :jti, null: false

      # Soft delete
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :jti, unique: true
    add_index :users, :employee_id, unique: true
    add_index :users, :ic_number, unique: true, where: "ic_number IS NOT NULL"
    add_index :users, :discarded_at

    add_check_constraint :users, "preferred_locale IN ('en', 'ms')", name: "check_users_preferred_locale"
  end
end
