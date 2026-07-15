require "test_helper"

module Manifests
  class SetCrewTest < ActiveSupport::TestCase
    test "snapshots companies_crew fields onto crew_manifests" do
      manifest = create(:manifest)
      crew = create(:companies_crew, :approved, company_profile: manifest.company_profile, crew_name: "Ali",
                                                ic_number: "01-123456", nationality: "Bruneian")

      SetCrew.call(manifest, crew_ids: [crew.id])

      snapshot = manifest.crew_manifests.sole

      assert_equal "Ali", snapshot.crew_name
      assert_equal "01-123456", snapshot.ic_number
      assert_equal crew.id, snapshot.companies_crew_id
    end

    test "supports ad hoc crew with no companies_crew record" do
      manifest = create(:manifest)

      SetCrew.call(manifest, ad_hoc_crew: [{ crew_name: "Guest Crew", nationality: "Malaysian" }])

      snapshot = manifest.crew_manifests.sole

      assert_equal "Guest Crew", snapshot.crew_name
      assert_nil snapshot.companies_crew_id
    end

    test "replace-all: a second call replaces the previous crew list rather than appending" do
      manifest = create(:manifest)
      first_crew = create(:companies_crew, :approved, company_profile: manifest.company_profile)
      second_crew = create(:companies_crew, :approved, company_profile: manifest.company_profile)

      SetCrew.call(manifest, crew_ids: [first_crew.id])

      assert_equal 1, manifest.crew_manifests.count

      SetCrew.call(manifest, crew_ids: [second_crew.id])

      assert_equal [second_crew.id], manifest.crew_manifests.pluck(:companies_crew_id)
    end
  end
end
