class Nationality < ApplicationRecord
  validates :name, presence: true, uniqueness: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[id name code is_local_citizenship created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end

# == Schema Information
#
# Table name: nationalities
# Database name: primary
#
#  id                   :uuid             not null, primary key
#  code                 :string
#  is_local_citizenship :boolean          default(FALSE), not null
#  name                 :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_nationalities_on_code  (code)
#  index_nationalities_on_name  (name) UNIQUE
#
