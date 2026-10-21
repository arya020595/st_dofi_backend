class AddFlowBKeptUniqueIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  class MigrationUser < ActiveRecord::Base
    self.table_name = "users"
  end

  def up
    assert_no_kept_normalized_ic_collisions!
    assert_no_kept_contact_collisions!

    remove_index :users, name: "index_users_on_ic_number", algorithm: :concurrently, if_exists: true
    add_index :users, :ic_number, algorithm: :concurrently, name: "index_users_on_ic_number"

    add_index :users, :normalized_ic_number,
              unique: true,
              algorithm: :concurrently,
              where: "normalized_ic_number IS NOT NULL AND discarded_at IS NULL",
              name: "index_users_on_normalized_ic_number_kept_unique"
    add_index :users, :company_profile_contact_id, unique: true, algorithm: :concurrently,
                                                   where: "company_profile_contact_id IS NOT NULL " \
                                                          "AND discarded_at IS NULL",
                                                   name: "index_users_on_company_profile_contact_id_kept_unique"
  end

  def down
    remove_index :users, name: "index_users_on_company_profile_contact_id_kept_unique", algorithm: :concurrently,
                         if_exists: true
    remove_index :users, name: "index_users_on_normalized_ic_number_kept_unique", algorithm: :concurrently,
                         if_exists: true
    remove_index :users, name: "index_users_on_ic_number", algorithm: :concurrently, if_exists: true
    add_index :users, :ic_number, unique: true, algorithm: :concurrently, where: "ic_number IS NOT NULL",
                                  name: "index_users_on_ic_number"
  end

  private

  def assert_no_kept_normalized_ic_collisions!
    duplicates = MigrationUser.where(discarded_at: nil)
                              .where.not(normalized_ic_number: nil)
                              .group(:normalized_ic_number)
                              .having("count(*) > 1")
                              .pluck(:normalized_ic_number)
    return if duplicates.empty?

    raise ActiveRecord::IrreversibleMigration,
          "Cannot add normalized IC unique index; duplicate kept normalized_ic_number values: #{duplicates.join(', ')}"
  end

  def assert_no_kept_contact_collisions!
    duplicates = MigrationUser.where(discarded_at: nil)
                              .where.not(company_profile_contact_id: nil)
                              .group(:company_profile_contact_id)
                              .having("count(*) > 1")
                              .pluck(:company_profile_contact_id)
    return if duplicates.empty?

    raise ActiveRecord::IrreversibleMigration,
          "Cannot add contact unique index; duplicate kept company_profile_contact_id values: #{duplicates.join(', ')}"
  end
end
