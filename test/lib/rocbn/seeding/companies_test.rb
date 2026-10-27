require "test_helper"

module Rocbn
  module Seeding
    class CompaniesTest < ActiveSupport::TestCase
      AUTOFILL_COLUMNS = %w[registration_no name address_1 telp district mukim village].freeze

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

      test "every synthetic company has every value needed to autofill a profile" do
        incomplete = @rows.filter_map do |row|
          missing = AUTOFILL_COLUMNS.select do |column|
            value = row[column].to_s.strip
            value.blank? || Rocbn::NotProvidedText::MARKERS.include?(value.downcase)
          end
          "#{row['id']}: #{missing.join(', ')}" if missing.any?
        end

        assert_empty incomplete, "incomplete ROCBN synthetic rows: #{incomplete.join('; ')}"
      end

      test "covers registry quirks that do not make autofill fields null" do
        assert(@rows.any? { |row| row["deleted_at"] })
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
