module CompaniesFishingGears
  # Single source of truth for the denormalized FishingGear fields a company's gear registration
  # carries — see docs/data-model/denormalized-snapshots.md. Both Create and Update need the exact
  # same field shape, so it lives here rather than being defined independently in each.
  class Snapshots
    def self.fishing_gear(fishing_gear_id)
      fishing_gear = FishingGear.find_by(id: fishing_gear_id)
      { fishing_gear_name: fishing_gear&.name, fishing_gear_type: fishing_gear&.gear_type,
        fishing_gear_fee: fishing_gear&.fee }
    end
  end
end
