class CompanyProfileContact < ApplicationRecord
  include Discard::Model

  belongs_to :company_profile
  has_many :users, dependent: :nullify

  validates :full_name, :ic_no, :gender, :ic_colour, :designation, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[id full_name ic_no gender ic_colour designation discarded_at created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
