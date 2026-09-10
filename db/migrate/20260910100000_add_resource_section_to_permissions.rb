class AddResourceSectionToPermissions < ActiveRecord::Migration[8.1]
  def change
    # Presentation/grouping metadata for the "Add User Role" UI only — never used for authorization,
    # which stays entirely Permission#code-based. resource is backfilled/kept in sync from code and
    # will be made NOT NULL once populated (see the following two migrations); section/section_order/
    # resource_order stay nullable indefinitely since ad-hoc/test permissions (see
    # test/factories/permissions.rb, test/test_helper.rb#find_or_create_permissions) use resource
    # values outside the curated Permission::PERMISSION_TAXONOMY.
    safety_assured do
      change_table :permissions, bulk: true do |t|
        t.string :resource
        t.string :section
        t.integer :section_order
        t.integer :resource_order
      end
    end
  end
end
