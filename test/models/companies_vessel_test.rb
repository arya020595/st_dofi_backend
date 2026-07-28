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
