#!/bin/bash
# Init hook of the rocbn-mysql service (docker-compose.yml / docker-compose.staging.yml), the stand-in for the
# client's read-only ROCBN registry. The mysql image runs it once, on the first start of an empty data volume,
# after 01-schema.sql (db/rocbn/schema.sql) created tdd_db.sync_rocbn_hotel. The image itself already created
# $MYSQL_USER (rocbn_seed, ALL on tdd_db: used by `rocbn:seed` and the tests). This adds what it cannot:
#   * rocbn_reader, the runtime account: SELECT on that one table only, like the account production should use;
#   * ${MYSQL_DATABASE}_test, the database the test suite uses (docs/rocbn/company-lookup.md).
# Passwords are interpolated into SQL, so generate them as hex (openssl rand -hex 16): no quotes or backslashes.
# Calls the mysql client explicitly (not the image's docker_process_sql helper) because the image sources a .sh
# file or executes it depending on its exec bit, and only a sourced file can see the helper.
mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" <<SQL
CREATE USER IF NOT EXISTS 'rocbn_reader'@'%' IDENTIFIED BY '${ROCBN_READER_PASSWORD}';
GRANT SELECT ON \`${MYSQL_DATABASE}\`.\`sync_rocbn_hotel\` TO 'rocbn_reader'@'%';
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}_test\`;
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}_test\`.* TO '${MYSQL_USER}'@'%';
SQL
