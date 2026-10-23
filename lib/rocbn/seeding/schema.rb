module Rocbn
  module Seeding
    # Creates sync_rocbn_hotel from db/rocbn/schema.sql where it does not exist yet. The file is CREATE TABLE IF NOT
    # EXISTS, so running it against a database that has the table changes nothing.
    class Schema
      PATH = Rails.root.join("db/rocbn/schema.sql")

      def self.load!(record_class) = record_class.lease_connection.execute(File.read(PATH))
    end
  end
end
