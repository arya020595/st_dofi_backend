class Role < ApplicationRecord
  DOFI_OFFICER = "DoFi Officer".freeze
  JETTY_MANAGER = "Jetty Manager".freeze
  FISHERMAN = "Fisherman".freeze
  SYSTEM_KINDS = [DOFI_OFFICER, JETTY_MANAGER, FISHERMAN].freeze
  EXTERNAL_KINDS = [JETTY_MANAGER, FISHERMAN].freeze # self-registration-only roles, never admin-creatable

  has_many :permission_roles, dependent: :destroy
  has_many :permissions, through: :permission_roles
  has_many :users, dependent: :nullify

  validates :name, presence: true, uniqueness: true
  validates :kind, inclusion: { in: SYSTEM_KINDS }, uniqueness: true, allow_nil: true

  def external? = EXTERNAL_KINDS.include?(kind)

  def self.ransackable_attributes(_auth_object = nil)
    %w[id kind name description created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
