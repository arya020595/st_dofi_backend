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

  test "is invalid without a required field" do
    %i[crew_name date_of_birth ic_number nationality position gender foreign_worker_license_no
       foreign_worker_license_start_date foreign_worker_license_end_date].each do |field|
      crew = build(:companies_crew, field => nil)

      assert_not crew.valid?, "expected crew without #{field} to be invalid"
      assert_includes crew.errors.attribute_names, field
    end
  end

  test "defaults to active status" do
    crew = create(:companies_crew)

    assert_equal "active", crew.status
  end

  test "is invalid with a status outside the allowed list" do
    crew = build(:companies_crew, status: "suspended")

    assert_not crew.valid?
    assert_includes crew.errors.attribute_names, :status
  end
end
