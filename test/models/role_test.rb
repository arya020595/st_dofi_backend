require "test_helper"

class RoleTest < ActiveSupport::TestCase
  test "identifies system managed fisherman Owner and Admin roles by flags not name alone" do
    company_profile = create(:company_profile)
    owner = create(:role, :fisherman, company_profile: company_profile, name: "Owner", is_default: true)
    admin = create(:role, :fisherman, company_profile: company_profile, name: "Admin", is_default_admin: true)
    custom = build(:role, :fisherman, company_profile: company_profile, name: "Owner")

    assert_predicate owner, :fisherman_owner_role?
    assert_predicate admin, :fisherman_admin_role?
    assert_not custom.fisherman_owner_role?
  end

  test "rejects reserved fisherman role names for custom roles case insensitively" do
    company_profile = create(:company_profile)

    %w[Owner owner OWNER Admin admin ADMIN].each do |name|
      role = build(:role, :fisherman, company_profile: company_profile, name: name)

      assert_not role.valid?, "#{name} should be reserved"
      assert_includes role.errors.attribute_names, :name
    end
  end

  test "prevents renaming system managed fisherman roles" do
    company_profile = create(:company_profile)
    owner = create(:role, :fisherman, company_profile: company_profile, name: "Owner", is_default: true)
    admin = create(:role, :fisherman, company_profile: company_profile, name: "Admin", is_default_admin: true)

    owner.name = "Superadmin"
    admin.name = "Manager"

    assert_not owner.valid?
    assert_not admin.valid?
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
#  is_default_admin   :boolean          default(FALSE), not null
#  kind               :string
#  name               :string           not null
#  platform_scope     :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  company_profile_id :uuid
#
# Indexes
#
#  index_roles_on_company_profile_id                       (company_profile_id)
#  index_roles_on_company_profile_id_and_is_default        (company_profile_id) UNIQUE WHERE (is_default = true)
#  index_roles_on_company_profile_id_and_is_default_admin  (company_profile_id) UNIQUE WHERE (is_default_admin = true)
#  index_roles_on_company_profile_id_and_name              (company_profile_id,name) UNIQUE NULLS NOT DISTINCT
#  index_roles_on_kind                                     (kind) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (company_profile_id => company_profiles.id)
#
