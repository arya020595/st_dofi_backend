class CompaniesCaptain < ApplicationRecord
  include Discard::Model
  include Approvable

  belongs_to :company_profile

  validates :captain_name, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[id captain_name date_of_birth ic_number passport_number nationality approval_status
       company_profile_id discarded_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
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
