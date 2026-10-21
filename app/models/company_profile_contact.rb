class CompanyProfileContact < ApplicationRecord
  include Discard::Model

  belongs_to :company_profile
  has_many :users, dependent: :nullify

  audited

  validates :full_name, :ic_no, :gender, :ic_colour, :designation, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[id full_name ic_no gender ic_colour designation discarded_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end

# == Schema Information
#
# Table name: company_profile_contacts
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  designation        :string
#  discarded_at       :datetime
#  full_name          :string
#  gender             :string
#  ic_colour          :string
#  ic_no              :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  company_profile_id :uuid             not null
#
# Indexes
#
#  index_company_profile_contacts_on_company_profile_id  (company_profile_id)
#  index_company_profile_contacts_on_discarded_at        (discarded_at)
#  index_company_profile_contacts_on_ic_no               (ic_no)
#
# Foreign Keys
#
#  fk_rails_...  (company_profile_id => company_profiles.id)
#
