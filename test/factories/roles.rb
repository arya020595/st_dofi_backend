FactoryBot.define do
  factory :role do
    sequence(:name) { |n| "Test Role #{n}" }
    description { "A test role" }
    platform_scope { Role::DOFI_OFFICER_PLATFORM }

    trait :fisherman do
      platform_scope { Role::FISHERMAN_PLATFORM }
      company_profile { association :company_profile }
    end
  end
end

# == Schema Information
#
# Table name: roles
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  description        :text
#  is_default         :boolean          default(FALSE), not null
#  kind               :string
#  name               :string           not null
#  platform_scope     :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  company_profile_id :uuid
#
# Indexes
#
#  index_roles_on_company_profile_id                 (company_profile_id)
#  index_roles_on_company_profile_id_and_is_default  (company_profile_id) UNIQUE WHERE (is_default = true)
#  index_roles_on_company_profile_id_and_name        (company_profile_id,name) UNIQUE NULLS NOT DISTINCT
#  index_roles_on_kind                               (kind) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (company_profile_id => company_profiles.id)
#
