module Manifests
  class OfflineBundle
    def self.call(...) = new.call(...)

    # Flow 4 (business-flow.md): reference data a fisherman needs cached client-side before losing
    # signal at sea, bundled alongside the manifest itself in one response.
    def call(manifest)
      {
        manifest: ManifestDetailBlueprint.render_as_hash(manifest),
        zones: ZoneBlueprint.render_as_hash(Zone.all),
        fishing_gears: FishingGearBlueprint.render_as_hash(FishingGear.all),
        company_fishing_gears: CompaniesFishingGearBlueprint.render_as_hash(company_fishing_gears(manifest)),
        dictionaries: DictionaryBlueprint.render_as_hash(Dictionary.all),
        skip_reasons: ManifestSkipReasonBlueprint.render_as_hash(ManifestSkipReason.kept)
      }
    end

    private

    def company_fishing_gears(manifest)
      manifest.company_profile.companies_fishing_gears.kept.approved
              .where(companies_vessel_id: manifest.companies_vessel_id)
    end
  end
end
