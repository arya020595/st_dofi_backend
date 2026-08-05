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

# == Schema Information
#
# Table name: companies_captains
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  amendment_remarks  :text
#  approval_status    :string           default("pending"), not null
#  approved_at        :datetime
#  captain_name       :string           not null
#  date_of_birth      :date
#  discarded_at       :datetime
#  ic_number          :string
#  nationality        :string
#  passport_number    :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  approved_by_id     :uuid
#  company_profile_id :uuid             not null
#
# Indexes
#
#  index_companies_captains_on_approval_status     (approval_status)
#  index_companies_captains_on_approved_by_id      (approved_by_id)
#  index_companies_captains_on_company_profile_id  (company_profile_id)
#  index_companies_captains_on_discarded_at        (discarded_at)
#
# Foreign Keys
#
#  fk_rails_...  (approved_by_id => users.id)
#  fk_rails_...  (company_profile_id => company_profiles.id)
#
