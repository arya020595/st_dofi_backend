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
