class ValidateForeignKeyFishingGearDetailOnFishCaptureDetails < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :fish_capture_details, :fishing_gear_details
  end
end
