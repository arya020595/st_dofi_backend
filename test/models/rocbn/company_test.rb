require "test_helper"

module Rocbn
  class CompanyTest < ActiveSupport::TestCase
    include RocbnTestSupport

    PERSON_COLUMNS = %w[role type_of_role identity_type identity_number nationality person_name date_of_birth
                        position gender appointment_date old_value].freeze

    test "kept hides the registry's soft-deleted rows" do
      kept = insert_rocbn_company
      deleted = insert_rocbn_company(deleted_at: Time.utc(2026, 1, 1))

      assert_includes Company.kept, kept
      assert_not_includes Company.kept, deleted
    end

    test "for_listing reads only the list columns, ordered by name then id" do
      second = insert_rocbn_company(name: "B CO")
      first = insert_rocbn_company(name: "A CO")
      tie = insert_rocbn_company(name: "B CO")

      listed = Company.for_listing.where(id: [first.id, second.id, tie.id])

      assert_equal [first.id, second.id, tie.id], listed.map(&:id)
      assert_equal %w[id registration_no name address_1 address_2 address_3], listed.first.attributes.keys
    end

    test "the director and shareholder columns are never loaded" do
      assert_empty Company.column_names & PERSON_COLUMNS
    end

    test "a company cannot be created, changed or destroyed" do
      company = insert_rocbn_company

      assert_raises(ActiveRecord::ReadOnlyRecord) { Company.new(registration_no: "RCX", name: "X").save! }
      assert_raises(ActiveRecord::ReadOnlyRecord) { company.update!(name: "Renamed") }
      assert_raises(ActiveRecord::ReadOnlyRecord) { company.destroy }
    end

    test "the registry's not-provided markers read back as nil, real values untouched" do
      company = insert_rocbn_company(district: "Belait", mukim: "-", village: " n/a ", telp: "Not Specified",
                                     address_2: "")

      assert_equal "Belait", company.district
      assert_equal [nil, nil, nil, nil], [company.mukim, company.village, company.contact_number, company.address_2]
    end

    test "company_address joins the address lines that were provided" do
      company = insert_rocbn_company(address_1: "No. 1077, Jln Mumong", address_2: "-", address_3: "Kuala Belait")

      assert_equal "No. 1077, Jln Mumong, Kuala Belait", company.company_address
      assert_nil insert_rocbn_company(address_1: "N/A").company_address
    end

    test "the API names read the registry's columns" do
      company = insert_rocbn_company(registration_no: "RCABC123", name: "NAMED CO", telp: "2345678")

      assert_equal ["RCABC123", "NAMED CO", "2345678"],
                   [company.rocbn_number, company.company_name, company.contact_number]
    end

    test "company_name_cont matches a part of the name, ignoring case and extra whitespace" do
      company = insert_rocbn_company(name: "AMIIRUL FISH CO.")

      assert_includes Company.ransack(company_name_cont: "amiirul").result, company
      assert_includes Company.ransack(company_name_cont: "  Amiirul    fish ").result, company
    end

    test "company_name_cont treats % and _ as plain characters" do
      percent = insert_rocbn_company(name: "100% FRESH")
      underscore = insert_rocbn_company(name: "UNDER_SCORE")
      decoys = [insert_rocbn_company(name: "1000 FRESH"), insert_rocbn_company(name: "UNDERXSCORE")]
      ids = [percent, underscore, *decoys].map(&:id)

      assert_equal [percent], Company.ransack(company_name_cont: "100%").result.where(id: ids).to_a
      assert_equal [underscore], Company.ransack(company_name_cont: "under_score").result.where(id: ids).to_a
    end

    test "rocbn_number_eq is an exact match that ignores case" do
      company = insert_rocbn_company(registration_no: "RCABC123")
      other = insert_rocbn_company(registration_no: "RCABC1234")

      found = Company.ransack(rocbn_number_eq: "rcabc123").result

      assert_includes found, company
      assert_not_includes found, other
    end

    test "search input is never interpolated into SQL" do
      company = insert_rocbn_company(name: "SAFE CO")

      assert_empty Company.ransack(company_name_cont: "x' OR '1'='1").result
      assert_includes Company.kept, company
    end

    test "a client sort cannot change the order" do
      sql = Company.for_listing.ransack(s: "company_name desc").result.to_sql

      assert_no_match(/DESC/i, sql)
    end
  end
end
