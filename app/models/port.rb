class Port < ApplicationRecord
  validates :port_name, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[id port_name latitude longitude created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end

# == Schema Information
#
# Table name: ports
# Database name: primary
#
#  id         :uuid             not null, primary key
#  latitude   :decimal(10, 8)
#  longitude  :decimal(11, 8)
#  port_name  :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_ports_on_port_name  (port_name)
#
