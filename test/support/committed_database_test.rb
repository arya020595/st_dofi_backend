# Tests using real commits need rows visible on independent PostgreSQL connections. Each parallel
# worker owns its database; remove only rows inserted by this test, preserving any pre-existing data.
module CommittedDatabaseTest
  def before_setup
    connection = ActiveRecord::Base.connection
    @original_row_ids = connection.tables.filter_map do |table|
      next if %w[schema_migrations ar_internal_metadata].include?(table)
      next unless connection.primary_key(table) == "id"

      [table, connection.select_values("SELECT id FROM #{connection.quote_table_name(table)}")]
    end.to_h
    super
  end

  def after_teardown
    connection = ActiveRecord::Base.connection
    connection.transaction do
      connection.disable_referential_integrity do
        remove_inserted_rows(connection)
      end
    end
  ensure
    super
  end

  private

  def remove_inserted_rows(connection)
    (@original_row_ids || {}).each do |table, ids|
      quoted_table = connection.quote_table_name(table)
      predicate = ids.empty? ? "" : " WHERE id NOT IN (#{ids.map { |id| connection.quote(id) }.join(', ')})"
      connection.execute("DELETE FROM #{quoted_table}#{predicate}")
    end
  end
end
