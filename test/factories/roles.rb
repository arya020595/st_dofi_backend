FactoryBot.define do
  factory :role do
    sequence(:name) { |n| "Test Role #{n}" }
    description { "A test role" }
  end
end

# == Schema Information
#
# Table name: roles
# Database name: primary
#
#  id          :uuid             not null, primary key
#  description :text
#  kind        :string
#  name        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_roles_on_kind  (kind) UNIQUE
#  index_roles_on_name  (name) UNIQUE
#
