class CompanyProfile < ApplicationRecord
  include Discard::Model

  belongs_to :approved_by_user, class_name: "User", foreign_key: "approved_by", inverse_of: false, optional: true
  has_many :users, dependent: :nullify

  validates :reference_id, presence: true, uniqueness: true
  validates :registration_type, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[id reference_id dofi_registration_no registration_type company_name rocbn_no full_name ic_no
       approval_status discarded_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
