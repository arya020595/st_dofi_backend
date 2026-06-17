class EnableExtensions < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pgcrypto" # gen_random_uuid()
    enable_extension "pg_trgm" # trigram search for species lookup
  end
end
