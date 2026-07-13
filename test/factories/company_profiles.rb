FactoryBot.define do
  factory :company_profile do
    registration_type { "Commercial" }
    company_name { "Azri Fish Sdn Bhd" }
    company_address { "Spg 10, Pantai Serasa, Mukim Serasa" }
    rocbn_no { "RC20390923" }
    contact_no { "71111111" }
    district { "Brunei - Muara" }
    mukim { "Serasa" }
    village { "Kapok" }
    sequence(:fisherman_card_no) { |n| "R-2026-#{format('%06d', n)}" }
    issue_date { Date.new(2026, 1, 1) }
    license_expiry_date { Date.new(2026, 12, 31) }
    worker_quota { 34 }
  end
end

# == Schema Information
#
# Table name: company_profiles
# Database name: primary
#
#  id                   :uuid             not null, primary key
#  amendment_remarks    :text
#  approval_status      :string           default("pending"), not null
#  approved_at          :datetime
#  approved_by          :uuid
#  company_address      :text
#  company_name         :string
#  contact_no           :string
#  date_approval        :date
#  designation          :string
#  discarded_at         :datetime
#  district             :string
#  dofi_registration_no :string
#  fisherman_card_no    :string
#  full_address         :string
#  full_name            :string
#  gender               :string
#  ic_colour            :string
#  ic_no                :string
#  issue_date           :date
#  license_expiry_date  :date
#  logo_url             :string
#  mukim                :string
#  registration_type    :string           not null
#  rocbn_no             :string
#  village              :string
#  worker_quota         :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_company_profiles_on_approval_status  (approval_status)
#  index_company_profiles_on_approved_by      (approved_by)
#  index_company_profiles_on_discarded_at     (discarded_at)
#  index_company_profiles_on_ic_no            (ic_no)
#  index_company_profiles_on_rocbn_no         (rocbn_no)
#
# Foreign Keys
#
#  fk_rails_...  (approved_by => users.id)
#
