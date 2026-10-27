module Rocbn
  module Seeding
    # The synthetic registry: the hand-written rows of db/rocbn/companies.yml plus a numbered block that spans several
    # pages. Fixed ids from 9,000,001 and no randomness, so a run is repeatable and running it again only updates
    # the same rows. Entirely fictional; none of it is real registry data.
    module Companies
      ID_BASE = 9_000_000
      PAGINATION_ROWS = 35
      FILE = Rails.root.join("db/rocbn/companies.yml")

      # The company-level columns of sync_rocbn_hotel. The person-level ones (director/shareholder) stay NULL.
      COLUMNS = %w[
        id registration_no name address_1 address_2 address_3 mukim village district postal_code country contact telp
        fax created_at updated_at deleted_at entity_id status incorporation_date nature_of_business business_sector_code
      ].freeze

      DEFAULTS = {
        "country" => "BN", "status" => "Registered", "nature_of_business" => "Private Company",
        "created_at" => "2025-09-20 08:07:30", "updated_at" => "2026-10-22 16:39:09"
      }.freeze

      def self.rows
        (written_by_hand + pagination_block).map do |attributes|
          full = DEFAULTS.merge(attributes)
          COLUMNS.index_with { |column| full[column] }
        end
      end

      def self.written_by_hand = YAML.safe_load_file(FILE)

      # "PAGINATION FISH TRADING 01 SDN BHD" .. "35": one search, several pages.
      def self.pagination_block
        (1..PAGINATION_ROWS).map do |number|
          {
            "id" => ID_BASE + 100 + number, "registration_no" => format("RC9%07d", 100 + number),
            "name" => format("PAGINATION FISH TRADING %02d SDN BHD", number),
            "address_1" => "Unit #{number}, Kompleks Perikanan Muara", "mukim" => "Serasa", "village" => "Kg Serasa",
            "district" => "Brunei Muara", "telp" => format("27%05d", number)
          }
        end
      end
    end
  end
end
