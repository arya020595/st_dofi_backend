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

# == Schema Information
#
# Table name: companies_fishing_gears
# Database name: primary
#
#  id                  :uuid             not null, primary key
#  amendment_remarks   :text
#  approval_status     :string           default("pending"), not null
#  approved_at         :datetime
#  discarded_at        :datetime
#  fishing_gear_fee    :decimal(10, 2)
#  fishing_gear_name   :string
#  fishing_gear_type   :string
#  local_name          :string
#  quantity            :integer
#  usage_value         :decimal(10, 2)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  approved_by_id      :uuid
#  companies_vessel_id :uuid
#  company_profile_id  :uuid             not null
#  fishing_gear_id     :uuid             not null
#
# Indexes
#
#  index_companies_fishing_gears_on_approval_status      (approval_status)
#  index_companies_fishing_gears_on_approved_by_id       (approved_by_id)
#  index_companies_fishing_gears_on_companies_vessel_id  (companies_vessel_id)
#  index_companies_fishing_gears_on_company_profile_id   (company_profile_id)
#  index_companies_fishing_gears_on_discarded_at         (discarded_at)
#  index_companies_fishing_gears_on_fishing_gear_id      (fishing_gear_id)
#
# Foreign Keys
#
#  fk_rails_...  (approved_by_id => users.id)
#  fk_rails_...  (companies_vessel_id => companies_vessels.id)
#  fk_rails_...  (company_profile_id => company_profiles.id)
#  fk_rails_...  (fishing_gear_id => fishing_gears.id)
#
