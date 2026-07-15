require "test_helper"

class CompaniesCrewTest < ActiveSupport::TestCase
  test "approve! transitions pending to approved" do
    crew = create(:companies_crew)

    crew.approve!

    assert_equal "approved", crew.approval_status
  end

  test "request_amendment! then resubmit! cycles back to pending" do
    crew = create(:companies_crew)

    crew.request_amendment!(remarks: "IC number invalid")

    assert_equal "amendment_required", crew.approval_status

    crew.resubmit!

    assert_equal "pending", crew.approval_status
  end
end
