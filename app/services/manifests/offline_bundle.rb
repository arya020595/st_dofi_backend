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
        company_fishing_gears: CompaniesFishingGearBlueprint.render_as_hash(
          manifest.company_profile.companies_fishing_gears.kept.approved
        ),
        dictionaries: DictionaryBlueprint.render_as_hash(Dictionary.all),
        skip_reasons: ManifestSkipReasonBlueprint.render_as_hash(ManifestSkipReason.kept)
      }
    end
  end
end
