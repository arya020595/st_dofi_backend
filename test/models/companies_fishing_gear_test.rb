require "test_helper"

class CompaniesFishingGearTest < ActiveSupport::TestCase
  test "approve! transitions pending to approved" do
    gear = create(:companies_fishing_gear)

    gear.approve!

    assert_equal "approved", gear.approval_status
  end

  test "request_amendment! then resubmit! cycles back to pending" do
    gear = create(:companies_fishing_gear)

    gear.request_amendment!(remarks: "Quantity looks wrong")

    assert_equal "amendment_required", gear.approval_status

    gear.resubmit!

    assert_equal "pending", gear.approval_status
  end
end
