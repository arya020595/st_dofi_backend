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

# == Schema Information
#
# Table name: companies_crews
# Database name: primary
#
#  id                                :uuid             not null, primary key
#  amendment_remarks                 :text
#  approval_status                   :string           default("pending"), not null
#  approved_at                       :datetime
#  crew_name                         :string           not null
#  date_of_birth                     :date
#  discarded_at                      :datetime
#  foreign_worker_license_end_date   :date
#  foreign_worker_license_no         :string
#  foreign_worker_license_start_date :date
#  gender                            :string
#  ic_number                         :string
#  nationality                       :string
#  passport_number                   :string
#  status                            :string           default("active"), not null
#  created_at                        :datetime         not null
#  updated_at                        :datetime         not null
#  approved_by_id                    :uuid
#  company_profile_id                :uuid             not null
#  position_id                       :uuid
#
# Indexes
#
#  index_companies_crews_on_approval_status     (approval_status)
#  index_companies_crews_on_approved_by_id      (approved_by_id)
#  index_companies_crews_on_company_profile_id  (company_profile_id)
#  index_companies_crews_on_discarded_at        (discarded_at)
#  index_companies_crews_on_position_id         (position_id)
#  index_companies_crews_on_status              (status)
#
# Foreign Keys
#
#  fk_rails_...  (approved_by_id => users.id)
#  fk_rails_...  (company_profile_id => company_profiles.id)
#  fk_rails_...  (position_id => positions.id)
#
