module Rocbn
  # Read-only diagnostics for the ROCBN connection (`bin/rails rocbn:check`), safe in every environment: it only issues
  # SELECT and SHOW on the read-only runtime connection and never prints the password. It answers what comes up when
  # wiring the real server: can we reach it, as which account and with which privileges, does the table still have
  # what the lookup reads (the registry is managed elsewhere and can change), and how big is it.
  class Check
    # What search and detail read. A table missing any of these would break the lookup, so it fails the check.
    REQUIRED_COLUMNS = (Company::LIST_COLUMNS.map(&:to_s) + %w[telp district mukim village deleted_at]).freeze
    READ_ONLY_PRIVILEGES = %w[SELECT USAGE].freeze
    # Fixed statements, no interpolation: the table is the one this lookup is about.
    KEPT_ROWS_SQL = "SELECT COUNT(*) FROM sync_rocbn_hotel WHERE deleted_at IS NULL".freeze
    DELETED_ROWS_SQL = "SELECT COUNT(*) FROM sync_rocbn_hotel WHERE deleted_at IS NOT NULL".freeze
    SHARED_NUMBERS_SQL = "SELECT COUNT(*) - COUNT(DISTINCT registration_no) FROM sync_rocbn_hotel".freeze

    def self.call(...) = new(...).call

    def initialize(out: $stdout, model: Company)
      @out = out
      @model = model
    end

    # True when the registry is usable. A privilege beyond SELECT is only a warning.
    def call
      @out.puts "ROCBN registry check"
      line("target", target)
      line("server", "MySQL #{value('SELECT VERSION()')}, signed in as #{value('SELECT CURRENT_USER()')}")
      report_privileges
      missing = missing_columns
      report_table(missing)
      missing.empty?
    rescue *BaseRecord::UNAVAILABLE_ERRORS => e
      line("connection", "FAILED (#{e.class}: #{e.message.lines.first&.strip})")
      false
    end

    private

    def target
      config = @model.connection_db_config.configuration_hash
      "#{config[:host]}:#{config[:port]}/#{config[:database]} as #{config[:username]}"
    end

    def report_privileges
      extra = connection.select_values("SHOW GRANTS FOR CURRENT_USER()").flat_map { |grant| privileges_in(grant) }
      line("privileges", privilege_summary(extra - READ_ONLY_PRIVILEGES))
    end

    def privilege_summary(extra)
      return "SELECT only" if extra.empty?

      "WARNING: also holds #{extra.uniq.join(', ')} (SELECT is enough)"
    end

    def privileges_in(grant)
      list = grant[/\AGRANT (.+?) ON /, 1]
      list ? list.split(",").map { |privilege| privilege.strip.upcase } : []
    end

    def missing_columns = REQUIRED_COLUMNS - connection.columns(@model.table_name).map(&:name)

    def report_table(missing)
      if missing.any?
        line("table", "FAILED, #{@model.table_name} lacks: #{missing.join(', ')}")
      else
        line("table", "#{@model.table_name} has every column the lookup reads")
        report_rows
      end
    end

    def report_rows
      line("rows", "#{value(KEPT_ROWS_SQL)} kept, #{value(DELETED_ROWS_SQL)} soft-deleted")
      line("duplicates", "#{value(SHARED_NUMBERS_SQL)} extra row(s) share a registration_no (informational)")
    end

    def value(sql) = connection.select_value(sql)
    def connection = @model.lease_connection
    def line(label, text) = @out.puts(format("  %<label>-11s %<text>s", label: label, text: text))
  end
end
