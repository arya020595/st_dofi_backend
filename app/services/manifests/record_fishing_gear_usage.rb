module Manifests
  # Adds the quantities recorded on a completed manifest's capture reports to each fishing gear's lifetime
  # usage_value. Writes another model's table, so it lives here rather than in Manifest.
  class RecordFishingGearUsage
    def self.call(...) = new.call(...)

    def call(manifest)
      usage_totals(manifest).each do |gear_id, quantity|
        CompaniesFishingGear.where(id: gear_id)
                            .update_all(["usage_value = COALESCE(usage_value, 0) + ?", quantity]) # rubocop:disable Rails/SkipsModelValidations
      end
    end

    private

    def usage_totals(manifest)
      FishingGearDetail.joins(:capture_report)
                       .where(capture_reports: { manifest_id: manifest.id })
                       .where.not(companies_fishing_gear_id: nil)
                       .group(:companies_fishing_gear_id)
                       .sum(:quantity)
    end
  end
end
