FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    name { "Test User" }
    sequence(:employee_id) { |n| "EMP-#{n}" }
    sequence(:username) { |n| "user#{n}" }
    password { "Password123!" }
    password_confirmation { "Password123!" }
    status { "active" }
    preferred_locale { "en" }
    role
  end
end

# == Schema Information
#
# Table name: users
# Database name: primary
#
#  id                         :uuid             not null, primary key
#  brunei_id_verified_at      :datetime
#  contact_no                 :string
#  designation                :string
#  discarded_at               :datetime
#  doft_registration_no       :string
#  email                      :string           default(""), not null
#  encrypted_password         :string           default(""), not null
#  ic_number                  :string
#  jti                        :string           not null
#  name                       :string           not null
#  position                   :string
#  preferred_locale           :string           default("en"), not null
#  registration_type          :string
#  rejection_reason           :text
#  remember_created_at        :datetime
#  reset_password_sent_at     :datetime
#  reset_password_token       :string
#  status                     :string           default("active"), not null
#  unit                       :string
#  username                   :string
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  company_profile_contact_id :uuid
#  company_profile_id         :uuid
#  employee_id                :string
#  role_id                    :uuid
#
# Indexes
#
#  index_users_on_company_profile_contact_id  (company_profile_contact_id)
#  index_users_on_company_profile_id          (company_profile_id)
#  index_users_on_discarded_at                (discarded_at)
#  index_users_on_email                       (email) UNIQUE WHERE ((email)::text <> ''::text)
#  index_users_on_employee_id                 (employee_id) UNIQUE
#  index_users_on_ic_number                   (ic_number) UNIQUE WHERE (ic_number IS NOT NULL)
#  index_users_on_jti                         (jti) UNIQUE
#  index_users_on_reset_password_token        (reset_password_token) UNIQUE
#  index_users_on_role_id                     (role_id)
#  index_users_on_username                    (username) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (company_profile_contact_id => company_profile_contacts.id)
#  fk_rails_...  (company_profile_id => company_profiles.id)
#  fk_rails_...  (role_id => roles.id)
#
