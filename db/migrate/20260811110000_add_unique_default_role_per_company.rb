class AddUniqueDefaultRolePerCompany < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  class MigrationRole < ActiveRecord::Base
    self.table_name = "roles"
  end

  # Defensive, not just additive: the existing (company_profile_id, name) unique index doesn't stop
  # two *differently-named* roles both being is_default: true for the same company. Verified via a
  # pre-flight query against the real DB that no duplicates exist today (Roles::EnsureFishermanOwnerRole
  # already keys its find_or_create_by! on this exact pair, so none were expected) — but this migration
  # stays self-contained and safe to run against any environment's actual state regardless, rather than
  # assuming what was true locally still holds everywhere.
  def up
    dedupe_is_default_roles

    add_index :roles, :company_profile_id, unique: true, where: "is_default = true",
                                           algorithm: :concurrently,
                                           name: "index_roles_on_company_profile_id_and_is_default"
  end

  def down
    remove_index :roles, name: "index_roles_on_company_profile_id_and_is_default"
  end

  private

  def dedupe_is_default_roles
    duplicate_company_ids = MigrationRole.where(is_default: true)
                                         .group(:company_profile_id)
                                         .having("count(*) > 1")
                                         .pluck(:company_profile_id)

    duplicate_company_ids.each do |company_profile_id|
      keep, *extras = MigrationRole.where(is_default: true, company_profile_id: company_profile_id)
                                   .order(:created_at)
      Rails.logger.warn(
        "AddUniqueDefaultRolePerCompany: company_profile_id=#{company_profile_id} had " \
        "#{extras.size + 1} is_default roles — keeping #{keep.id}, unsetting #{extras.map(&:id)}"
      )
      # rubocop:disable Rails/SkipsModelValidations
      MigrationRole.where(id: extras.map(&:id)).update_all(is_default: false)
      # rubocop:enable Rails/SkipsModelValidations
    end
  end
end
