class CreateCaptureReports < ActiveRecord::Migration[8.1]
  def change
    create_table :capture_reports, id: :uuid do |t|
      t.string :reference_id, null: false # CR-001 (auto-generated per manifest)
      t.references :manifest, null: false, foreign_key: true, type: :uuid
      t.references :zone, foreign_key: true, type: :uuid
      t.string :zone_area # Denormalized snapshot ("Zone 1A Keatas")
      t.decimal :longitude, precision: 11, scale: 8
      t.decimal :latitude, precision: 10, scale: 8

      # Capture report verification status, reviewed by DoFi Officer.
      # Values: pending_verification | verified | needs_amendment
      t.string :capture_report_status, null: false, default: "pending_verification"
      t.text :capture_report_remarks # Remarks from DoFi Officer on rejection

      # Reviewed by info, visible in "Reviewed By" section on the capture report form
      t.references :reviewed_by, type: :uuid, foreign_key: { to_table: :users }
      t.datetime :reviewed_at

      t.timestamps
    end

    add_index :capture_reports, :reference_id
    add_index :capture_reports, :capture_report_status
  end
end
