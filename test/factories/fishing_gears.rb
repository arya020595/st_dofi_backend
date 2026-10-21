FactoryBot.define do
  factory :fishing_gear do
    sequence(:local_name) { |n| "Pukat #{n}" }
    sequence(:name) { |n| "Gear #{n}" }
    gear_type { "Net" }
    fee { 10.0 }
  end
end

# == Schema Information
#
# Table name: fishing_gears
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  fee                :decimal(10, 2)
#  gear_specification :string
#  gear_type          :string           not null
#  local_name         :string
#  name               :string           not null
#  size               :decimal(10, 2)
#  unit               :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_fishing_gears_on_gear_type  (gear_type)
#  index_fishing_gears_on_name       (name)
#
