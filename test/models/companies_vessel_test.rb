require "test_helper"

class CompaniesVesselTest < ActiveSupport::TestCase
  test "approve! transitions pending to approved and stamps the approver" do
    officer = create(:user)
    vessel = create(:companies_vessel)

    vessel.approve!(actor: officer)

    assert_equal "approved", vessel.approval_status
    assert_equal officer.id, vessel.approved_by_id
    assert_not_nil vessel.approved_at
  end

  test "approve! raises when the vessel is not pending" do
    vessel = create(:companies_vessel, :approved)

    assert_raises(AASM::InvalidTransition) { vessel.approve! }
    assert_not vessel.may_approve?
  end

  test "request_amendment! moves to amendment_required and records the remarks" do
    vessel = create(:companies_vessel)

    vessel.request_amendment!(remarks: "Boat number does not match ROCBN records")

    assert_equal "amendment_required", vessel.approval_status
    assert_equal "Boat number does not match ROCBN records", vessel.amendment_remarks
  end

  test "resubmit! cycles an amended vessel back to pending, clearing amendment_remarks" do
    vessel = create(:companies_vessel)
    vessel.request_amendment!(remarks: "Boat number does not match ROCBN records")

    vessel.resubmit!

    assert_equal "pending", vessel.approval_status
    assert_nil vessel.amendment_remarks
  end

  test "defaults to powered and permanent when not specified" do
    vessel = create(:companies_vessel)

    assert vessel.is_powered
    assert_equal "permanent", vessel.boat_type
  end

  test "is invalid with a boat_type outside the allowed list" do
    vessel = build(:companies_vessel, boat_type: "seasonal")

    assert_not vessel.valid?
    assert_includes vessel.errors.attribute_names, :boat_type
  end

  test "is invalid with a charter_type outside the allowed list" do
    vessel = build(:companies_vessel, charter_type: "leased")

    assert_not vessel.valid?
    assert_includes vessel.errors.attribute_names, :charter_type
  end

  test "allows charter_type to be nil" do
    vessel = build(:companies_vessel, charter_type: nil)

    assert_predicate vessel, :valid?
  end
end

# == Schema Information
#
# Table name: companies_vessels
# Database name: primary
#
#  id                  :uuid             not null, primary key
#  amendment_remarks   :text
#  approval_status     :string           default("pending"), not null
#  approved_at         :datetime
#  boat_number         :string           not null
#  boat_type           :string           default("permanent"), not null
#  capacity            :integer
#  category            :string
#  charter_type        :string
#  discarded_at        :datetime
#  draft               :decimal(10, 2)
#  engine_count        :integer
#  gross_tonnage       :decimal(10, 2)
#  horse_power         :decimal(10, 2)
#  is_powered          :boolean          default(TRUE), not null
#  length              :decimal(10, 2)
#  license_expiry_date :date
#  license_reg_date    :date
#  material            :string
#  max_crew            :integer
#  registration_no     :string
#  status              :string           default("active"), not null
#  vessel_name         :string           not null
#  year_built          :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  approved_by_id      :uuid
#  company_profile_id  :uuid             not null
#  zone_id             :uuid
#
# Indexes
#
#  index_companies_vessels_on_approval_status     (approval_status)
#  index_companies_vessels_on_approved_by_id      (approved_by_id)
#  index_companies_vessels_on_boat_number         (boat_number)
#  index_companies_vessels_on_company_profile_id  (company_profile_id)
#  index_companies_vessels_on_discarded_at        (discarded_at)
#  index_companies_vessels_on_registration_no     (registration_no)
#  index_companies_vessels_on_status              (status)
#  index_companies_vessels_on_zone_id             (zone_id)
#
# Foreign Keys
#
#  fk_rails_...  (approved_by_id => users.id)
#  fk_rails_...  (company_profile_id => company_profiles.id)
#  fk_rails_...  (zone_id => zones.id)
#
