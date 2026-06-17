class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  devise :database_authenticatable, :jwt_authenticatable, :validatable,
         jwt_revocation_strategy: self

  belongs_to :role, optional: true
  belongs_to :company_profile, optional: true

  VALID_LOCALES = %w[en ms].freeze

  validates :name, presence: true
  validates :preferred_locale, inclusion: { in: VALID_LOCALES }
end
