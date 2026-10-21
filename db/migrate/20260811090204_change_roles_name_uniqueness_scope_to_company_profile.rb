class ChangeRolesNameUniquenessScopeToCompanyProfile < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    safety_assured do
      remove_index :roles, :name, unique: true
    end

    add_index :roles, %i[company_profile_id name], unique: true, nulls_not_distinct: true,
                                                   algorithm: :concurrently,
                                                   name: "index_roles_on_company_profile_id_and_name"
  end
end
