FactoryBot.define do
  factory :port do
    sequence(:port_name) { |n| "Port #{n}" }
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
