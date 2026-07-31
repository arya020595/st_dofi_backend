class AddFishingGearDetailToFishCaptureDetails < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_reference :fish_capture_details, :fishing_gear_detail, type: :uuid, index: { algorithm: :concurrently }

    execute <<~SQL.squish
      UPDATE fish_capture_details
      SET fishing_gear_detail_id = matched.fishing_gear_detail_id
      FROM (
        SELECT DISTINCT ON (fcd.id) fcd.id AS fish_capture_detail_id, fgd.id AS fishing_gear_detail_id
        FROM fish_capture_details fcd
        JOIN fishing_gear_details fgd ON fgd.capture_report_id = fcd.capture_report_id
        WHERE fcd.fishing_gear_detail_id IS NULL
        ORDER BY fcd.id, fgd.created_at ASC
      ) AS matched
      WHERE fish_capture_details.id = matched.fish_capture_detail_id
    SQL
  end

  def down
    remove_reference :fish_capture_details, :fishing_gear_detail, index: { algorithm: :concurrently }
  end
end
