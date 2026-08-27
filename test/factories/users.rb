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

    # DOFI_OFFICER/JETTY_MANAGER-kind roles trigger User's role-scoped presence validations
    # (position/unit always; contact_no/ic_number for jetty_manager too) — these traits exist so
    # controller tests assigning an officer/jetty_manager-kind role don't each hand-roll the same
    # field set just to satisfy validation, not because the model needs them by default.
    trait :officer_shaped do
      position { "Administrator" }
      unit { "HQ" }
    end

    trait :jetty_manager_shaped do
      position { "Staff" }
      unit { "HQ" }
      contact_no { "71999999" }
      sequence(:ic_number) { |n| "71-#{100_000 + n}" }
    end
  end
end

# == Schema Information
#
# Table name: users
# Database name: primary
#
#  id                         :uuid             not null, primary key
#  approved_at                :datetime
#  brunei_id_verified_at      :datetime
#  claimed_at                 :datetime
#  contact_no                 :string
#  designation                :string
#  discarded_at               :datetime
#  doft_registration_no       :string
#  email                      :string           default(""), not null
#  encrypted_password         :string           default(""), not null
#  fisherman_status           :string
#  ic_number                  :string
#  jti                        :string           not null
#  name                       :string           not null
#  normalized_ic_number       :string
#  position                   :string
#  preferred_locale           :string           default("en"), not null
#  provisioning_source        :string
#  registration_type          :string
#  rejection_reason           :text
#  remember_created_at        :datetime
#  reset_password_sent_at     :datetime
#  reset_password_token       :string
#  revocation_comment         :text
#  revoked_at                 :datetime
#  status                     :string           default("active"), not null
#  unit                       :string
#  username                   :string
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  approved_by_id             :uuid
#  company_profile_contact_id :uuid
#  company_profile_id         :uuid
#  created_by_id              :uuid
#  employee_id                :string
#  revocation_remark_id       :uuid
#  revoked_by_id              :uuid
#  role_id                    :uuid
#
# Indexes
#
#  index_users_on_company_profile_contact_id              (company_profile_contact_id)
#  index_users_on_company_profile_contact_id_kept_unique  (company_profile_contact_id) UNIQUE WHERE ((company_profile_contact_id IS NOT NULL) AND (discarded_at IS NULL))
#  index_users_on_company_profile_id                      (company_profile_id)
#  index_users_on_discarded_at                            (discarded_at)
#  index_users_on_email                                   (email) UNIQUE WHERE ((email)::text <> ''::text)
#  index_users_on_employee_id                             (employee_id) UNIQUE
#  index_users_on_ic_number                               (ic_number)
#  index_users_on_jti                                     (jti) UNIQUE
#  index_users_on_normalized_ic_number_kept_unique        (normalized_ic_number) UNIQUE WHERE ((normalized_ic_number IS NOT NULL) AND (discarded_at IS NULL))
#  index_users_on_reset_password_token                    (reset_password_token) UNIQUE
#  index_users_on_revocation_remark_id                    (revocation_remark_id)
#  index_users_on_revoked_by_id                           (revoked_by_id)
#  index_users_on_role_id                                 (role_id)
#  index_users_on_username                                (username) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (approved_by_id => users.id)
#  fk_rails_...  (company_profile_contact_id => company_profile_contacts.id)
#  fk_rails_...  (company_profile_id => company_profiles.id)
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (revocation_remark_id => approval_remarks.id)
#  fk_rails_...  (revoked_by_id => users.id)
#  fk_rails_...  (role_id => roles.id)
#
