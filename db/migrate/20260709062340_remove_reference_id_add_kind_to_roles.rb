class RemoveReferenceIdAddKindToRoles < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      remove_index :roles, :reference_id
      remove_column :roles, :reference_id, :string, null: false

      # "kind" (not "type" — Rails reserves that name for STI) identifies the 3 fixed system roles
      # (DoFi Officer / Jetty Manager / Fisherman) that business logic keys off. Nullable so custom
      # roles created via the Roles API aren't forced into one of these 3 buckets; never exposed as
      # a writable API param (see RolesController#role_params) so it can only be set via seeds/console.
      add_column :roles, :kind, :string
      add_index :roles, :kind, unique: true
    end
  end
end
