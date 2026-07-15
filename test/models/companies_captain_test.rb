require "test_helper"

class CompaniesCaptainTest < ActiveSupport::TestCase
  test "approve! transitions pending to approved" do
    captain = create(:companies_captain)

    captain.approve!

    assert_equal "approved", captain.approval_status
  end

  test "request_amendment! then resubmit! cycles back to pending" do
    captain = create(:companies_captain)

    captain.request_amendment!(remarks: "Passport number missing")

    assert_equal "amendment_required", captain.approval_status

    captain.resubmit!

    assert_equal "pending", captain.approval_status
  end
end
