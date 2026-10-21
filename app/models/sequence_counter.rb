class SequenceCounter < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :value, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end

# == Schema Information
#
# Table name: sequence_counters
# Database name: primary
#
#  id         :uuid             not null, primary key
#  key        :string           not null
#  value      :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_sequence_counters_on_key  (key) UNIQUE
#
