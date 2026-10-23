require "test_helper"

module Rocbn
  class CheckTest < ActiveSupport::TestCase
    READER_GRANTS = ["GRANT USAGE ON *.* TO `reader`@`%`",
                     "GRANT SELECT ON `tdd_db`.`sync_rocbn_hotel` TO `reader`@`%`"].freeze
    CONFIG = { host: "registry.internal", port: 9139, database: "tdd_db", username: "reader",
               password: "never-printed" }.freeze

    # Just enough of the model and its connection for Check: what it asks the registry, scripted.
    ANSWERS = { "VERSION" => "8.0.0", "CURRENT_USER" => "reader@%" }.freeze

    FakeConnection = Struct.new(:grants, :columns_present) do
      def select_value(sql) = ANSWERS.find { |fragment, _| sql.include?(fragment) }&.last || 1
      def select_values(_sql) = grants
      def columns(_table) = columns_present.map { |name| Struct.new(:name).new(name) }
    end

    class FakeModel
      def initialize(connection) = @connection = connection
      def connection_db_config = Struct.new(:configuration_hash).new(CONFIG)
      def lease_connection = @connection.respond_to?(:call) ? @connection.call : @connection
      def table_name = "sync_rocbn_hotel"
    end

    test "a SELECT-only account on a complete table is a clean pass" do
      out = StringIO.new

      assert Check.call(out: out, model: model(READER_GRANTS))
      assert_match(/privileges  SELECT only/, out.string)
    end

    test "a privilege beyond SELECT is a warning, not a failure" do
      out = StringIO.new
      grants = ["GRANT ALL PRIVILEGES ON `tdd_db`.* TO `reader`@`%`"]

      assert Check.call(out: out, model: model(grants))
      assert_match(/WARNING: also holds ALL PRIVILEGES/, out.string)
    end

    test "a table missing a column the lookup reads fails the check" do
      out = StringIO.new
      incomplete = Check::REQUIRED_COLUMNS - ["telp"]

      assert_not Check.call(out: out, model: model(READER_GRANTS, columns: incomplete))
      assert_match(/lacks: telp/, out.string)
    end

    test "an unreachable registry fails the check with the reason, and never prints the password" do
      out = StringIO.new
      unreachable = FakeModel.new(-> { raise ActiveRecord::ConnectionNotEstablished, "no route to host" })

      assert_not Check.call(out: out, model: unreachable)
      assert_match(/FAILED \(ActiveRecord::ConnectionNotEstablished: no route to host\)/, out.string)
      assert_no_match(/never-printed/, out.string)
    end

    private

    def model(grants, columns: Check::REQUIRED_COLUMNS)
      FakeModel.new(FakeConnection.new(grants, columns))
    end
  end
end
