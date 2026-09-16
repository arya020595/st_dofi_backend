class AddCaptureReportNumberToCaptureReports < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :capture_reports, :capture_report_number, :string
    create_capture_report_number_sequence
    create_capture_report_number_trigger
    backfill_capture_report_numbers
    add_capture_report_number_index
    set_capture_report_number_not_null
  end

  def down
    remove_index :capture_reports, name: "index_capture_reports_on_number", algorithm: :concurrently
    drop_capture_report_number_trigger
    drop_capture_report_number_sequence
    remove_column :capture_reports, :capture_report_number
  end

  private

  def create_capture_report_number_sequence
    safety_assured do
      execute "CREATE SEQUENCE capture_report_number_sequence START WITH 1 INCREMENT BY 1 NO CYCLE"
    end
  end

  def create_capture_report_number_trigger
    safety_assured do
      execute <<~SQL.squish
        CREATE FUNCTION assign_capture_report_number()
        RETURNS trigger
        LANGUAGE plpgsql
        AS $$
        BEGIN
          NEW.capture_report_number := format(
            'CAPTURE-%s-%s',
            to_char(COALESCE(NEW.created_at, CURRENT_TIMESTAMP) AT TIME ZONE 'Asia/Brunei', 'YYYYMMDD'),
            lpad(nextval('capture_report_number_sequence')::text, 3, '0')
          );
          RETURN NEW;
        END;
        $$;

        CREATE TRIGGER set_capture_report_number_before_insert
        BEFORE INSERT ON capture_reports
        FOR EACH ROW
        EXECUTE FUNCTION assign_capture_report_number();
      SQL
    end
  end

  def backfill_capture_report_numbers
    safety_assured do
      execute <<~SQL.squish
        UPDATE capture_reports
        SET capture_report_number = format(
          'CAPTURE-%s-%s',
          to_char(created_at AT TIME ZONE 'Asia/Brunei', 'YYYYMMDD'),
          lpad(nextval('capture_report_number_sequence')::text, 3, '0')
        )
        WHERE capture_report_number IS NULL
      SQL
    end
  end

  def add_capture_report_number_index
    add_index :capture_reports,
              :capture_report_number,
              unique: true,
              algorithm: :concurrently,
              name: "index_capture_reports_on_number"
  end

  def set_capture_report_number_not_null
    safety_assured { change_column_null :capture_reports, :capture_report_number, false }
  end

  def drop_capture_report_number_trigger
    safety_assured do
      execute <<~SQL.squish
        DROP TRIGGER IF EXISTS set_capture_report_number_before_insert ON capture_reports;
        DROP FUNCTION IF EXISTS assign_capture_report_number();
      SQL
    end
  end

  def drop_capture_report_number_sequence
    safety_assured { execute "DROP SEQUENCE IF EXISTS capture_report_number_sequence" }
  end
end
