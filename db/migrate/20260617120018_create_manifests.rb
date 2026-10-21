class CreateManifests < ActiveRecord::Migration[8.1]
  def change
    create_table :manifests, id: :uuid do |t|
      t.string :manifest_number, null: false # DOF-20260101-001 (DOF-YYYYMMDD-NNN, auto-generated per day)

      # Fisherman category, denormalized from company_profile.registration_type for fast filtering.
      # Values: "commercial" | "small_scale_company" | "small_scale_full_time" | "small_scale_part_time"
      t.string :fisherman_category, null: false

      # Vessel / Boat
      t.references :companies_vessel, null: false, foreign_key: true, type: :uuid
      t.string :vessel_boat_no # Denormalized snapshot
      t.string :vessel_boat_name

      # Captain / Owner (optional for small-scale)
      t.references :companies_captain, foreign_key: true, type: :uuid
      t.string :captain_name # Denormalized snapshot
      t.string :captain_ic_number

      # Company
      t.references :company_profile, null: false, foreign_key: true, type: :uuid
      t.string :company_name # Denormalized snapshot

      # Port Out
      t.references :port_out, foreign_key: { to_table: :ports }, type: :uuid
      t.datetime :port_out_datetime
      t.string :port_out_area
      # port_out_status values by fisherman type:
      #   Commercial:   draft | pending | amendment_required | approved
      #   Small-Scale:  draft | submitted
      t.string :port_out_status, null: false, default: "draft"

      # Port In
      t.references :port_in, foreign_key: { to_table: :ports }, type: :uuid
      t.datetime :port_in_datetime
      t.string :port_in_area
      # port_in_status values by fisherman type:
      #   Commercial:   draft | pending | amendment_required | approved
      #   Small-Scale:  submitted
      t.string :port_in_status, null: false, default: "draft"

      # Zone
      t.references :zone, foreign_key: true, type: :uuid
      t.string :zone_area # Denormalized snapshot

      # GPS coordinates (catch area)
      t.decimal :longitude, precision: 11, scale: 8
      t.decimal :latitude, precision: 10, scale: 8

      # State machine column (overall manifest lifecycle)
      t.string :manifest_status, null: false, default: "draft"

      # Capture report skip, fisherman may skip capture report (no fish caught, engine issue, etc.)
      t.boolean :capture_report_skipped, null: false, default: false
      t.references :skip_reason, foreign_key: { to_table: :manifest_skip_reasons }, type: :uuid
      t.text :skip_reason_remarks

      # Minor fishermen flag, Small-Scale (Part-Time / Full-Time) only
      t.boolean :has_minor_fishermen, null: false, default: false

      # Audit
      t.references :created_by, type: :uuid, foreign_key: { to_table: :users }
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :manifests, :manifest_number, unique: true
    add_index :manifests, :manifest_status
    add_index :manifests, :fisherman_category
    add_index :manifests, :port_out_status
    add_index :manifests, :port_in_status
    add_index :manifests, :capture_report_skipped
    add_index :manifests, :discarded_at
  end
end
