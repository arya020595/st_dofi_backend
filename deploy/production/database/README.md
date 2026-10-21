# Database server: native PostgreSQL 16

PostgreSQL 16 installed from Ubuntu's own repository (`apt`), run by `systemd`. No Docker on this host. The host
(`OGCMPT003API001`, 10.252.8.23) also runs MySQL 8.0 for another system; PostgreSQL is a separate package, on its own
port (5432) and data directory (`/var/lib/postgresql/16/main`), and does not touch MySQL.

Needs: `sudo` on the host, the backend server's IP (10.252.8.12), and this host's private IP (10.252.8.23).
Replace `<DB_IP>` and `<BACKEND_IP>` below with them. Docker is only a fallback: [`docker/`](docker/).

## 0. Look first (read-only)

```bash
lsb_release -a; free -h; nproc; df -h        # Ubuntu 24.04 expected; RAM, CPU, disk for sizing
systemctl is-active ufw                      # is the host firewall on?
ss -lnt                                      # port 5432 must be free (add sudo and -p to see which process owns 9139: not ours)
```

## 1. Install

```bash
sudo apt update && sudo apt install -y postgresql-16   # creates cluster 16/main on :5432; includes pg_trgm and pgcrypto
```

## 2. Configure

A drop-in file, so the packaged `postgresql.conf` stays untouched. `shared_buffers` is about 25% of the RAM that
MySQL leaves free (size it from `free -h`; 1GB is a placeholder).

```bash
sudo tee /etc/postgresql/16/main/conf.d/dofi.conf <<'EOF'
listen_addresses = 'localhost,<DB_IP>'
max_connections = 100
shared_buffers = 1GB
password_encryption = scram-sha-256
log_min_duration_statement = 1000
EOF
```

Allow only the backend server to log in as `dofi` (the default `pg_hba.conf` has no remote rule):

```bash
echo 'host  all  dofi  <BACKEND_IP>/32  scram-sha-256' | sudo tee -a /etc/postgresql/16/main/pg_hba.conf
```

## 3. Create the application role

Not a superuser. `CREATEDB` lets Rails `db:prepare` create its four databases, and it owns them, so it can create the
`pg_trgm` and `pgcrypto` extensions (both are "trusted" extensions in PostgreSQL 13+). Choose the password
interactively so it does not land in shell history, and **save it**: it is the backend's `DATABASE_PASSWORD`.

```bash
sudo -u postgres psql
postgres=# CREATE ROLE dofi LOGIN CREATEDB;
postgres=# \password dofi
postgres=# \q
```

## 4. Host firewall and start

If `ufw` is active, allow SSH first, then the backend server. If it is inactive, leave it off: the client's network
firewall does the restricting (only the backend server may reach 5432).

```bash
sudo ufw status
sudo ufw allow from <BACKEND_IP> to any port 5432 proto tcp     # only if ufw is active
sudo systemctl restart postgresql     # listen_addresses needs a restart; MySQL is not affected
```

## 5. Verify

```bash
sudo ss -lntp | grep 5432                                    # listening on <DB_IP> and 127.0.0.1
sudo -u postgres psql -c 'SHOW listen_addresses;'
psql -h <DB_IP> -U dofi -d postgres -c 'select 1'            # from the BACKEND server: succeeds
psql -h <DB_IP> -U dofi -d postgres                          # wrong password: rejected
```

The four databases (`dofi_backend_production` and its `_cache`, `_queue`, `_cable`) are created by the backend's
first `db:prepare`; nothing to create by hand.

## 6. Backups (minimum, before go-live)

A nightly dump of the main database, kept 14 days, copied off the host by the client's process.

```bash
sudo install -d -o postgres -g postgres -m 700 /var/backups/dofi
sudo tee /usr/local/bin/dofi-backup <<'EOF'
#!/bin/sh
set -eu
dir=/var/backups/dofi
pg_dump -Fc dofi_backend_production > "$dir/primary-$(date +%F).dump"
find "$dir" -name 'primary-*.dump' -mtime +14 -delete
EOF
sudo chmod 755 /usr/local/bin/dofi-backup
echo '0 2 * * * postgres /usr/local/bin/dofi-backup' | sudo tee /etc/cron.d/dofi-backup
```

Restore drill (do it once before go-live):

```bash
sudo -u postgres createdb dofi_restore_test
sudo -u postgres pg_restore -d dofi_restore_test --clean --if-exists /var/backups/dofi/primary-<date>.dump
sudo -u postgres dropdb dofi_restore_test
```

## Upgrades

Security fixes for `postgresql-16` arrive through Ubuntu's normal updates (`unattended-upgrades` or `apt upgrade`);
a minor update restarts only the PostgreSQL service for a few seconds.
