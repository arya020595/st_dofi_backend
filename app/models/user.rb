class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher
  include Discard::Model

  devise :database_authenticatable, :jwt_authenticatable, :validatable,
         jwt_revocation_strategy: self

  belongs_to :role, optional: true
  belongs_to :company_profile, optional: true

  VALID_LOCALES = %w[en ms].freeze

  validates :name, presence: true
  validates :preferred_locale, inclusion: { in: VALID_LOCALES }

  def permission?(*codes)
    return false unless role

    role.permissions.exists?(code: codes)
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[id name email employee_id status preferred_locale unit position role_id doft_registration_no
       ic_number registration_type username_directory discarded_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
