class AddForeignKeyFishingGearDetailToFishCaptureDetails < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :fish_capture_details, :fishing_gear_details, validate: false
  end
end
