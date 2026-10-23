# Support for tests that exercise the ROCBN registry on a real MySQL: its LIKE and collation behaviour cannot be faked.
# The suite uses its own database (config/rocbn.yml `test`, ROCBN_TEST_DB_*), never the ROCBN_DB_* runtime variables,
# and refuses a host that is not local. Without a reachable MySQL these tests skip locally and fail under CI, so a
# missing service cannot go unnoticed there.
#
# Rails wraps each test in a transaction per database. test_helper opts :rocbn out for every test, so unrelated tests
# never connect to MySQL, and including this module opts it back in. Parallel workers share the database, but their
# uncommitted rows are invisible to each other, so a test must not insert explicit ids.
module RocbnTestSupport
  extend ActiveSupport::Concern

  # Runs when test_helper requires this file, before any test transaction opens: the DDL would implicitly commit one.
  # A failure is remembered and reported by each test instead of aborting the whole suite.
  def self.prepare!
    host = Rocbn::Company.connection_db_config.configuration_hash[:host]
    unless Rocbn::Seeding::Guard.local_host?(host)
      raise "Refusing to run tests against ROCBN host #{host.inspect}: not a local MySQL"
    end

    Rocbn::Seeding::Schema.load!(Rocbn::Company)
  rescue *Rocbn::BaseRecord::UNAVAILABLE_ERRORS => e
    @unavailable = "#{e.class}: #{e.message.lines.first&.strip}"
  ensure
    Rocbn::BaseRecord.connection_pool.disconnect!
  end

  def self.unavailable = @unavailable

  prepare!

  included do
    use_transactional_tests_for_database :rocbn, RocbnTestSupport.unavailable.nil?
    setup { require_registry! }
  end

  def require_registry!
    return unless RocbnTestSupport.unavailable

    message = "ROCBN test database unavailable (#{RocbnTestSupport.unavailable}); `docker compose up -d rocbn-mysql`"
    ENV["CI"].present? ? flunk(message) : skip(message)
  end

  # Every statement the block sends to the registry's connection, in order.
  def capture_registry_sql
    statements = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      statements << payload[:sql] if payload[:connection].is_a?(ActiveRecord::ConnectionAdapters::TrilogyAdapter)
    end
    yield
    statements
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  # Inserted with insert_all!: Rocbn::Company is read-only. Returns the row as the lookup reads it.
  def insert_rocbn_company(**attributes)
    row = { "registration_no" => "RCT#{SecureRandom.hex(4).upcase}", "name" => "TEST COMPANY" }
          .merge(attributes.stringify_keys)
    Rocbn::Company.insert_all!([row]) # rubocop:disable Rails/SkipsModelValidations
    Rocbn::Company.find_by!(registration_no: row["registration_no"])
  end
end
