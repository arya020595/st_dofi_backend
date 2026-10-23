require "test_helper"

module Rocbn
  module Seeding
    class CompaniesTest < ActiveSupport::TestCase
      setup { @rows = Companies.rows }

      test "every row has exactly the company columns" do
        assert(@rows.all? { |row| row.keys == Companies::COLUMNS })
      end

      test "ids are unique, fixed and inside the synthetic block" do
        ids = @rows.pluck("id")

        assert_equal ids.uniq, ids
        assert_operator ids.min, :>, Guard::SYNTHETIC_ID_FLOOR
      end

      test "ROCBN numbers are unique and shaped like the registry's" do
        numbers = @rows.pluck("registration_no")

        assert_equal numbers.uniq, numbers
        assert(numbers.all? { |number| number.match?(/\ARC\d{8}\z/) })
      end

      test "a run is repeatable: same rows every time" do
        assert_equal Companies.rows, Companies.rows
      end

      test "covers the registry's quirks: soft delete, not-provided markers, characters LIKE treats specially" do
        assert(@rows.any? { |row| row["deleted_at"] })
        assert(@rows.any? { |row| row["mukim"] == "-" })
        assert(@rows.any? { |row| row["name"].include?("%") })
      end

      test "has similarly named companies and enough numbered rows to page through" do
        similar = @rows.count { |row| row["name"].downcase.include?("amiirul") }
        numbered = @rows.count { |row| row["name"].start_with?("PAGINATION FISH TRADING") }

        assert_equal [3, Companies::PAGINATION_ROWS], [similar, numbered]
        assert_operator @rows.size, :>=, 50
      end

      test "the schema file is the registry's table, created only if missing, without its row counter" do
        sql = File.read(Schema::PATH)

        assert_match(/CREATE TABLE IF NOT EXISTS `sync_rocbn_hotel`/, sql)
        assert_no_match(/AUTO_INCREMENT=\d/, sql)
      end
    end
  end
end
