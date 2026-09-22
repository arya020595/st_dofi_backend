connection = ActiveRecord::Base.connection

connection.execute <<~SQL.squish
  CREATE SEQUENCE IF NOT EXISTS capture_report_number_sequence START WITH 1 INCREMENT BY 1 NO CYCLE;
  CREATE OR REPLACE FUNCTION assign_capture_report_number() RETURNS trigger LANGUAGE plpgsql AS $$
  BEGIN NEW.capture_report_number := format('CAPTURE-%s-%s',
  to_char(COALESCE(NEW.created_at, CURRENT_TIMESTAMP) AT TIME ZONE 'Asia/Brunei', 'YYYYMMDD'),
  lpad(nextval('capture_report_number_sequence')::text, 3, '0')); RETURN NEW; END; $$;
  DROP TRIGGER IF EXISTS set_capture_report_number_before_insert ON capture_reports;
  CREATE TRIGGER set_capture_report_number_before_insert BEFORE INSERT ON capture_reports
  FOR EACH ROW EXECUTE FUNCTION assign_capture_report_number();
SQL

connection.execute <<~SQL.squish
  CREATE SEQUENCE IF NOT EXISTS company_profile_number_sequence START WITH 1 INCREMENT BY 1 NO CYCLE;
  CREATE OR REPLACE FUNCTION assign_company_profile_number() RETURNS trigger LANGUAGE plpgsql AS $$
  BEGIN NEW.profile_number := format('DOF-%s',
  lpad(nextval('company_profile_number_sequence')::text, 4, '0')); RETURN NEW; END; $$;
  DROP TRIGGER IF EXISTS set_company_profile_number_before_insert ON company_profiles;
  CREATE TRIGGER set_company_profile_number_before_insert BEFORE INSERT ON company_profiles
  FOR EACH ROW EXECUTE FUNCTION assign_company_profile_number();
SQL
