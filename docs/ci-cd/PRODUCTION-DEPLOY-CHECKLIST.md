# Production deploy checklist (4 servers)

Step-by-step to-do for putting the backend, file storage and database on the client's servers, reached by IP
over plain HTTP (no domain or TLS yet; the backend sits behind nginx on port 3000). Every tick below has its commands
inline; the explanations are in [`deploy/README.md`](../../deploy/README.md), the
[backend runbook](../../deploy/production/backend/README.md) and the [database runbook](../../deploy/production/database/README.md);
the design is in [`production-4-server-architecture.md`](../architecture/production-4-server-architecture.md). Tick the boxes in order.

Servers (hostname, IP, role):

| Placeholder | Value | Server |
|---|---|---|
| `<BACKEND_IP>` | 10.252.8.12 | `OGCMET001API001`: nginx + Rails `api` + `jobs` |
| `<STORAGE_IP>` | 10.252.8.13 | `OGCMET001API002`: MinIO |
| `<DB_IP>` | 10.252.8.23 | `OGCMPT003API001`: PostgreSQL 16 (native) |
| `<FE_ORIGIN>` | `http://10.246.8.12:4100` | `OGCMET001WPD001`: frontend (confirm the IP, see section A) |

> **How releases work (the client's "Approach A").** A push or merge to `main` runs
> [`cd-production.yml`](../../.github/workflows/cd-production.yml): tests, then builds the image and pushes it to
> `ghcr.io`. It does **not** touch any server, because GitHub cannot reach the client's private network (the SSH deploy
> job is switched off). A person then pulls the new image on the backend server through Delinea: section E. Merging to
> `main` is therefore safe at any time. The compose file publishes the API on `127.0.0.1` only, so users reach it through
> nginx (section D).

## Progress (last updated 2026-10-27)

| Area | State |
|---|---|
| Database server (C1) and storage server (C2) | Set up earlier. Backend to database `5432` and backend to MinIO `9000` are open and **proven**: `db:prepare` created the four databases and uploaded 17 files to MinIO. |
| Backend server prepared (C3) | Done: Docker group, `/opt/dofi`, GHCR login, the three files (checksums match), `.env` filled and validated. `SENTRY_DSN` is set and tested (2026-10-27: an event reached Sentry); `BRUNEIID_*` is empty (not supplied yet); `ROCBN_DB_USERNAME=stuser`. |
| First run (D) | **Done 2026-10-27:** `pull`, `db:prepare`, `up -d --wait` (`api` and `jobs` healthy, image from `main` with the file relay), nginx vhost installed and the Ubuntu `default` site disabled, `rocbn:check` passes (185,324 rows). Frontend to backend works on **`http://10.252.8.12:3000`**: `/up` 200, CORS preflight allows `http://10.246.8.12:4100`, `/cable` upgrades (101). It needed nginx to listen on `10.252.8.12:3000` (and only there, no port 80) and a `firewalld` rich rule on the App server (runbook step 6); it was not the client's network. |
| Seed data | **Decided 2026-10-27: keep the demo data for testing on production, with dummy data only.** The demo accounts still have the default password `ChangeMe123!` (seeded by `db:prepare`, see the warning in section D); change at least `admin@dofi.gov.bn` now, and **reset the databases and change every seeded password before any real data goes in** (to do item 3 below). |
| Firewall, to request from the client | **Nothing left to request for the first round.** `9139` (ROCBN) is open and proven. Web to App `3000` is the client's own rule and works (the block was `firewalld` on our server, fixed). Users to storage `9000` is **not** requested: browsers reach only the Web server. BruneiID `443` waits for its hostname. **To ask the MySQL owner:** `stuser` holds `ALL PRIVILEGES` and may log in from any host (`rocbn:check` warns); the app only needs `SELECT` on `tdd_db.sync_rocbn_hotel`. |
| Not needed | LDAP/AD `3268/3269` (the app does not use it); MinIO console `9001` (not published). |
| File viewing (decision) | **Decided 2026-10-27: relay files through Rails.** The FE server may not reach storage either, and it proxies `/api` to the BE. Code is on branch `feat/relay-attachments` (tests, rubocop, rbac-lint, brakeman green; production route table has no Active Storage routes), **not yet merged, built or deployed**. The first deploy is not blocked: start the stack with the current image; until the relay image ships, testers can upload but not view files. Still to do: FE loader for Dictionary images, FE nginx proxy, FE to BE firewall port, run `dictionaries:migrate_images_to_minio` only if old blobs must move. |
| Upload regression (2026-10-27) | Uploads re-tested after the relay change: vessel images, company documents, Dictionary create and update, spoofed type rejected, and an upload-then-fetch round trip. Full suite 776 runs, 0 failures (3 unrelated ROCBN errors). Not run against a real MinIO; verify one upload and one view on the App server after deploy. Record: [`UPLOAD-REGRESSION-2026-10-27.md`](../minio/UPLOAD-REGRESSION-2026-10-27.md). |
| File viewing (analysis) | Client management drew "only the Back End talks to storage" and suggested NFS (2049) or SFTP (22). Our analysis, recommending to keep S3 on `9000` (already open) and build the relay: [`STORAGE-PROTOCOL-OPTIONS.md`](../minio/STORAGE-PROTOCOL-OPTIONS.md). Until it is released testers can upload but not view files. Open question for management. |

## To do, in order (added 2026-10-27, so nothing is forgotten)

The backend is deployed and reachable from the frontend server. Testing on production uses **dummy data only**. The list
has two parts: what happens during testing, and what must be finished **before real data** goes in.

### Now, during testing

- [ ] Change the password of `admin@dofi.gov.bn` (it is still `ChangeMe123!`, published in the repo). Type it on the backend server, never in chat:

  ```bash
  cd /opt/dofi
  read -rs -p "New admin password: " NEWPW; echo
  docker compose exec -e NEWPW="$NEWPW" api bin/rails runner '
    u = User.find_by!(email: "admin@dofi.gov.bn")
    u.update!(password: ENV["NEWPW"], password_confirmation: ENV["NEWPW"])
    puts "admin password updated"'
  unset NEWPW
  ```

- [ ] Frontend team: call the API at `http://10.252.8.12:3000`; one JWT-authenticated loader for Dictionary images (no bare `<img src>`); their nginx proxies `/api` and `/cable` with bodies of at least 12 MB. Brief: [`FE-DISCUSSION-FILE-DELIVERY.md`](../minio/FE-DISCUSSION-FILE-DELIVERY.md).
- [ ] Human end-to-end test from the frontend: log in, upload a vessel image and a PDF, open both again. This is the first real proof of upload and the file relay against the real MinIO (tests used the disk service); in the browser's Network tab no request may go to `10.252.8.13`. Record the result in [`UPLOAD-REGRESSION-2026-10-27.md`](../minio/UPLOAD-REGRESSION-2026-10-27.md).

### After testing, before real data (nothing here blocks testing)

| # | Item | Done when |
|---|---|---|
| 1 | **Backups.** Install the nightly `pg_dump` on the database server ([section G](#g-backups-minimum)) and copy it off the host. | A dump exists, is copied off-host, and one restore into a scratch database has been tested. |
| 2 | **ROCBN account.** Ask the MySQL owner to limit `stuser` to `SELECT` on `tdd_db.sync_rocbn_hotel`, ideally only from `10.252.8.12` (today: `ALL PRIVILEGES` from any host, flagged by `rocbn:check`). | `bin/rails rocbn:check` on the backend no longer prints the `ALL PRIVILEGES` warning and the lookup still works. |
| 3 | **Reset the demo data.** Reset the databases and seed reference data only, with `ADMIN_DEFAULT_PASSWORD` set before the first `db:prepare`; gate the demo seeds so they cannot run in production (small change in `db/seeds`, to write when the time comes). Only the databases on this server, only with explicit confirmation. | No `ChangeMe123!` account exists, no demo manifests or companies remain, reference data is back. |
| 4 | **BruneiID.** Get the host and credentials from the client, fill `BRUNEIID_*` in `/opt/dofi/.env`, register the redirect URI (it must match character for character: see the [post-mortem](../incidents/POSTMORTEM-2026-10-02-brunei-id-redirect-uri-mismatch.md)), and ask for outbound `443` to that host. | A Brunei ID login completes from the frontend. |
| 5 | **Domain and TLS.** HTTPS on the backend's nginx ([runbook, step 10](../../deploy/production/backend/README.md#10-later-a-domain-and-tls)), `FORCE_SSL=true`, `https://` origins in `CORS_ORIGINS` and `CABLE_ALLOWED_ORIGINS`, and `wss://` for the WebSocket. Tell the frontend team. | The frontend works over HTTPS with no mixed-content errors. |

Also open, lower priority: Sentry events need outbound `443` to `*.ingest.us.sentry.io` (works today; add it to the client's whitelist so it survives a firewall review), and the rest of [section I](#i-not-done-yet).

## A. Get from the client

- [ ] **The firewall rules, requested first.** Every later step needs them: `db:prepare` needs the database port, the Add Profiling company lookup needs the registry's MySQL port (row 12), the first boot needs MinIO, `docker pull` needs outbound access to `ghcr.io`. The table to send is [§3 of the architecture doc](../architecture/production-4-server-architecture.md#3-network-firewall-request); the client's change takes days, so ask before anything is deployed, not after. To prove each row is open, run [the connectivity check](NETWORK-CONNECTIVITY-CHECK.md).
- [ ] The four server IPs (private and, if different, the one browsers use). The database host is `OGCMPT003API001` (the client's name, per their screenshot).
- [ ] Working `sudo` on the database host (`localadmin`), and approval to install the `postgresql-16` package there. It already runs MySQL 8.0 for another system; ours is a separate package and port. Port 9139 is that MySQL, which also holds the ROCBN company registry we read (next item).
- [ ] **A MySQL account for the ROCBN registry** (status 2026-10-27: account `stuser` received and in the backend `.env`; port 9139 from the backend is still `Connection refused`, firewall row 12 to be followed up with the client; `SELECT`-only is not proven until `rocbn:check` runs) (the client's DBA creates it): `SELECT` on `tdd_db.sync_rocbn_hotel` only, allowed from the backend server's address (`10.252.8.12`). Ask which authentication plugin it uses; `caching_sha2_password` and `mysql_native_password` both work. Its username and password go into the backend `.env` (C3). The lookup is read-only by design, so an account that can do more should be refused: `rocbn:check` (section D) warns about it.
- [ ] Which networks (users' LAN/VPN) may reach the frontend `4100`, backend `80` (nginx; port 3000 stays internal) and storage `9000`; database `5432` only from the backend server.
- [ ] The outbound whitelist confirmed in writing, from the App Server on TCP 443: BruneiID host (`BRUNEIID_BASE_URL`), `ghcr.io`, `pkg-containers.githubusercontent.com`. For the fallback build (section J) also `ssh.github.com`, `github.com`, Docker Hub, Debian mirrors (80 and 443) and RubyGems; the exact list is in [the architecture doc, §3](../architecture/production-4-server-architecture.md#3-network-firewall-request). The storage server needs `ghcr.io` too, and the database server needs the Ubuntu apt mirrors.
- [ ] How we log in to the servers: Delinea SSH terminal over VPN. No inbound access from GitHub is needed or requested.
- [ ] The frontend's origin exactly as browsers use it, scheme and port included (for example `http://10.246.8.12:4100`): it goes into `CORS_ORIGINS` and `CABLE_ALLOWED_ORIGINS`. The architecture doc still has an open question on whether its IP is `.11` or `.12`.

## B. GitHub

Nothing on GitHub has to reach the servers, so there are no SSH keys or `PRODUCTION_SSH_*` secrets to create.

- [ ] The workflow "CD Production" is green on `main` once: `Test & Security`, then `Build & Push GHCR`. Check that `ghcr.io/arya020595/st_dofi_backend` has the tags `production` and the commit SHA (repo, Packages).
- [ ] `SLACK_WEBHOOK_URL` (optional): Slack then posts "image pushed, manual deployment required" after each build.
- [ ] A read-only token the servers use to pull the **private** images: GitHub, Settings, Developer settings, Personal access tokens (classic), scope `read:packages` only. Nothing renews it, so **write down its expiry date**: when it expires every `docker compose pull` fails with `unauthorized`. It is used for `docker login` on the backend server (C3) and the storage server (C2).
- [ ] Only if the client ever allows GitHub to SSH in: follow the steps in the comment above the `deploy` job in `cd-production.yml` (SSH key, `PRODUCTION_SSH_*` secrets, `production` environment reviewers, remove `if: ${{ false }}`). Not part of this checklist.

## C. Servers, in this order: database, storage, backend

Do each step on the server named. All commands run in the server's SSH or Delinea terminal.

### C1. Database server (`OGCMPT003API001`, native PostgreSQL 16, no Docker)

Replace `<DB_IP>` with 10.252.8.23 and `<BACKEND_IP>` with 10.252.8.12. Details: [database runbook](../../deploy/production/database/README.md).

- [ ] Look first (read-only). Ubuntu 24.04 expected; port 5432 must be free.

  ```bash
  lsb_release -a; free -h; nproc; df -h
  systemctl is-active ufw
  sudo ss -lntp | grep -E ':(5432|9139)\b'                  # 5432 must be absent; 9139 is the existing MySQL (the ROCBN registry, not ours)
  ```

- [x] Install PostgreSQL 16 (a separate package and port from the MySQL already on the host):

  ```bash
  sudo apt update && sudo apt install -y postgresql-16
  ```

- [x] Configure the drop-in file (the packaged `postgresql.conf` stays untouched) and allow only the backend server. Size `shared_buffers` at about 25% of the RAM MySQL leaves free (`free -h`); 1GB is a placeholder.

  First keep a copy of the original rules file and check the IP belongs to this host (stop if the second command prints nothing):

  ```bash
  sudo cp -a /etc/postgresql/16/main/pg_hba.conf /etc/postgresql/16/main/pg_hba.conf.orig
  ip -4 addr | grep <DB_IP>
  ```

  Then, once only (the `echo` appends, so a second run duplicates the rule):

  ```bash
  sudo tee /etc/postgresql/16/main/conf.d/dofi.conf <<'EOF'
  listen_addresses = 'localhost,<DB_IP>'
  max_connections = 100
  shared_buffers = 1GB
  password_encryption = scram-sha-256
  log_min_duration_statement = 1000
  EOF
  echo 'host  all  dofi  <BACKEND_IP>/32  scram-sha-256' | sudo tee -a /etc/postgresql/16/main/pg_hba.conf
  ```

  Replace `<DB_IP>` and `<BACKEND_IP>` with the real addresses before running. A terminal can mangle a pasted multi-line block, so read back what was written before restarting:

  ```bash
  cat /etc/postgresql/16/main/conf.d/dofi.conf     # exactly the five lines above
  sudo tail -n 2 /etc/postgresql/16/main/pg_hba.conf    # root and postgres only can read it; the last line is the dofi rule
  ```

- [x] Create the `dofi` role (`LOGIN CREATEDB`, not superuser). Type the password interactively so it stays out of shell history, and **save it** for the backend `.env` (`DATABASE_PASSWORD`).

  ```bash
  sudo -u postgres psql
  postgres=# CREATE ROLE dofi LOGIN CREATEDB;
  postgres=# \password dofi
  postgres=# \q
  ```

- [x] Open the host firewall only if `ufw` is active (SSH first), then restart PostgreSQL (`listen_addresses` needs a restart; MySQL is not affected):

  ```bash
  sudo ufw status
  sudo ufw allow from <BACKEND_IP> to any port 5432 proto tcp     # only if ufw is active
  sudo systemctl restart postgresql
  ```

  If PostgreSQL does not start, or you need to back out any of these changes, see [Undo and troubleshooting](../../deploy/production/database/README.md#undo-and-troubleshooting).

- [ ] Check:

  ```bash
  sudo ss -lntp | grep 5432                                  # listening on <DB_IP> and 127.0.0.1
  sudo -u postgres psql -c 'SHOW listen_addresses;'
  # later, from the BACKEND server:
  nc -vz <DB_IP> 5432                                        # succeeded
  psql -h <DB_IP> -U dofi -d postgres -c 'select 1'          # needs the postgresql-client package; wrong password must be rejected
  ```

  The four databases (`dofi_backend_production` and its `_cache`, `_queue`, `_cable`) are created by the backend's first `db:prepare`; create nothing by hand.

- [ ] Add a nightly backup (section G).

### C2. Storage server (`OGCMET001API002`, MinIO in Docker)

Replace `<GITHUB_USER>` with the GitHub account that owns the read-only token. Details: [`deploy/README.md`](../../deploy/README.md).

- [x] Install Docker Engine and the Compose plugin, put the deploy user in the `docker` group, and create `/opt/dofi` (done on `OGCMET001API002` from Docker's official apt repository, `download.docker.com`, which that host can reach; the Ubuntu packages below also work):

  ```bash
  docker --version; docker compose version                  # skip the install if both already print a version
  sudo apt update && apt-cache policy docker.io docker-compose-v2     # both need a Candidate (Ubuntu 24.04 universe)
  sudo apt install -y docker.io docker-compose-v2            # Ubuntu's own packages: no extra apt repository to whitelist
  sudo usermod -aG docker "$USER"                            # log out and back in afterwards
  docker --version; docker compose version; docker info > /dev/null && echo docker-ok
  sudo mkdir -p /opt/dofi && sudo chown "$USER": /opt/dofi
  ```

- [x] Log in to the registry (the MinIO image is a private mirror). `read -s` keeps the token out of the history:

  ```bash
  read -rs GHCR_TOKEN && echo "$GHCR_TOKEN" | docker login ghcr.io -u <GITHUB_USER> --password-stdin; unset GHCR_TOKEN
  ```

- [x] Copy three files from the repo to `/opt/dofi` (from a machine with the repo; through Delinea, paste each into `nano` instead):

  ```bash
  scp deploy/production/storage/docker-compose.yml deploy/production/storage/.env.example docker/mc-init.sh <user>@<STORAGE_IP>:/opt/dofi/
  ```

- [x] Create and fill `.env`. **Save the bucket names and the two access key pairs** for the backend `.env`.

  ```bash
  cd /opt/dofi && cp .env.example .env && chmod 600 .env
  openssl rand -hex 32          # run once per secret: MINIO_ROOT_PASSWORD, MINIO_SECRET_ACCESS_KEY, MINIO_ASSETS_SECRET_ACCESS_KEY
  nano .env                     # MINIO_ROOT_USER, MINIO_ROOT_PASSWORD, MINIO_ACCESS_KEY_ID, MINIO_SECRET_ACCESS_KEY,
                                # MINIO_ASSETS_ACCESS_KEY_ID, MINIO_ASSETS_SECRET_ACCESS_KEY (bucket names keep their defaults)
  ```

- [x] Start MinIO and create the buckets and the app's access keys (`mc-init` is safe to re-run):

  ```bash
  cd /opt/dofi
  docker compose up -d --wait && docker compose run --rm mc-init
  ```

- [ ] Check:

  ```bash
  docker compose ps                                          # minio: Up (healthy)
  curl -i http://<STORAGE_IP>:9000/minio/health/live         # 200
  ```

### C3. Backend server (`OGCMET001API001`): prepare

Docker and nginx are installed. Full explanations: [backend runbook](../../deploy/production/backend/README.md) (step numbers in brackets).

- [x] Look first, read-only (step 0). A failure here is a firewall or server-order problem, not something to fix on this server. (2026-10-27: DB 5432, MinIO 9000 and ghcr.io all `OPEN`; Docker 29.9.2, Compose v5.6.0, nginx 1.24; `:80` is nginx, `:3000` free. Only `default` is in `sites-enabled`. Registry `9139` not checked yet.)

  ```bash
  lsb_release -a; free -h; nproc; df -h
  docker --version; docker compose version
  nginx -v; systemctl is-active nginx ufw
  ls /etc/nginx/sites-enabled                                # only `default` expected; any other site is not ours: leave it
  sudo ss -lntp | grep -E ':(80|3000)\b'                     # 80 = nginx; 3000 must be free
  nc -vz <DB_IP> 5432; nc -vz <STORAGE_IP> 9000              # needs C1 and C2 done and firewall rows 4 and 5; fuller version: NETWORK-CONNECTIVITY-CHECK.md
  curl -sI https://ghcr.io | head -1                         # firewall row 7
  ```

- [x] The deploy user (`localadmin`) is in the `docker` group and owns `/opt/dofi` (step 1; CD runs `docker` without `sudo`); done 2026-10-27:

  ```bash
  sudo usermod -aG docker "$USER"                            # log out and back in afterwards
  docker info > /dev/null && echo docker-ok
  sudo mkdir -p /opt/dofi/nginx && sudo chown -R "$USER": /opt/dofi
  ```

- [x] Log in to the registry with the read-only token from B (done 2026-10-27, `Login Succeeded` as `arya020595`; the token is stored unencrypted in `~/.docker/config.json`, so keep that file `600`). Every release pulls with this login; if a later `pull` says `unauthorized`, the token expired: repeat this (step 2):

  ```bash
  read -rs GHCR_TOKEN && echo "$GHCR_TOKEN" | docker login ghcr.io -u <GITHUB_USER> --password-stdin; unset GHCR_TOKEN
  ```

- [x] Copy the three files to `/opt/dofi` (step 3; done 2026-10-27 through Delinea). Where `scp` may not work, paste each file into `nano` instead, or send it as one line of base64 (a multi-line paste can be mangled by the terminal) and compare the checksum afterwards:

  ```bash
  # from a machine with the repo
  scp deploy/production/backend/docker-compose.yml deploy/production/backend/.env.example <user>@<BACKEND_IP>:/opt/dofi/
  scp deploy/production/backend/nginx/dofi-api.conf <user>@<BACKEND_IP>:/opt/dofi/nginx/

  # Delinea alternative. On the machine with the repo, print one line per file:
  for f in docker-compose.yml .env.example nginx/dofi-api.conf; do
    echo "echo '$(base64 -w0 deploy/production/backend/$f)' | base64 -d > /opt/dofi/$f"
  done
  sha256sum deploy/production/backend/{docker-compose.yml,.env.example,nginx/dofi-api.conf} | cut -c1-12,65-
  # Paste each printed line on the server, then run the same sha256sum there (cd /opt/dofi) and compare the first 12 characters.
  ```

- [x] Create `/opt/dofi/.env` and fill it in (step 3; done 2026-10-27 with `BRUNEIID_*` and `SENTRY_DSN` still empty, the client has not supplied them; `ROCBN_DB_USERNAME=stuser`). Fill the secrets without echoing them: a small `setenv KEY` function that does `read -rs` and rewrites that one line of `.env`, so nothing lands in the shell history or in a chat:

  ```bash
  cd /opt/dofi && cp .env.example .env && chmod 600 .env
  openssl rand -hex 32          # DEVISE_JWT_SECRET_KEY (changing it later signs every user out)
  nano .env
  ```

  | Variable | Value |
  |---|---|
  | `RAILS_MASTER_KEY` | content of `config/master.key` from the repo owner's checkout; without it the app does not boot |
  | `DEVISE_JWT_SECRET_KEY` | the `openssl rand -hex 32` output |
  | `FORCE_SSL` | `false` (no certificate yet) |
  | `DATABASE_HOST`, `DATABASE_PASSWORD` | `<DB_IP>` and the `dofi` role's password from C1; `DATABASE_USERNAME` stays `dofi` |
  | `CORS_ORIGINS`, `CABLE_ALLOWED_ORIGINS` | `<FE_ORIGIN>` in both: scheme, host and port exactly as the browser shows it, no trailing slash |
  | `MINIO_ENDPOINT`, `MINIO_PUBLIC_ENDPOINT` | both `http://<STORAGE_IP>:9000` |
  | `MINIO_BUCKET`, `MINIO_ASSETS_BUCKET` and the four access/secret keys | copied from the storage server's `.env` (C2) |
  | `ROCBN_DB_HOST`, `ROCBN_DB_PORT`, `ROCBN_DB_NAME` | `10.252.8.23`, `9139`, `tdd_db` (already in `.env.example`) |
  | `ROCBN_DB_USERNAME`, `ROCBN_DB_PASSWORD` | the registry account from section A. Never set `ROCBN_SEED_*`, `ROCBN_TEST_*` or `ROCBN_ALLOW_SEED` here: production is never seeded |
  | `BRUNEIID_*` | from the client; `BRUNEIID_REDIRECT_URI` must match the URI registered at BruneiID character for character |

- [x] Validate it (2026-10-27: `env-ok`, mode `600`, master key 32 characters, JWT secret 64, no CR, no trailing space or quotes). `-q` prints nothing on success; plain `docker compose config` would print the secrets. To list which keys are filled without showing values: `awk -F= '/^[A-Z_]+=/ {print $1, ($2=="" ? "EMPTY" : "set")}' .env`. The MinIO key pairs must be copied from the storage server's `.env`, never regenerated: `mc-init` registered exactly those pairs in MinIO:

  ```bash
  cd /opt/dofi && docker compose config -q && echo env-ok
  ```

## D. First run by hand, with nginx in front (required once)

This is the first release, and it also sets up nginx and the firewall, which releases never touch. C1 and C2 must be running first: `db:prepare` creates the four databases and seeds reference data including images.

- [ ] Start the stack (backend runbook step 4):

  ```bash
  cd /opt/dofi
  docker compose pull
  docker compose run --rm api bin/rails db:prepare           # creates the 4 databases, seeds reference data
  docker compose up -d
  docker compose ps                                          # api and jobs: Up
  docker compose logs --tail 50 api jobs                     # no stack traces
  curl -i http://127.0.0.1:3000/up                           # 200 (works only from this host)
  ```

  If `pull` says the `:production` tag is not found, the image was never built: merge to `main` and wait for the green `Build & Push GHCR` job (section B).

  **Status 2026-10-27:** `pull` and `db:prepare` done on the backend server. The four databases were created, the migrations and seeds ran, and 17 files were uploaded to MinIO, which proves backend to database and backend to MinIO. `up -d`, `ps`, logs and `/up` are still to do.

  > **Warning: `db:prepare` on a new database runs the whole `db/seeds.rb`, which is not only reference data.** It also created demo records: 16 company profiles, 21 vessels, 23 crew, 24 fisherman users, 1 jetty manager, the Brunei ID sandbox users, and 11 manifests with notifications. The admin `admin@dofi.gov.bn` and the seeded users get the default password `ChangeMe123!` unless `ADMIN_DEFAULT_PASSWORD` is set in `.env` **before** the first `db:prepare` (it only applies when the row is created). Decide before opening port 80 to users: keep the demo data for acceptance testing and change every seeded password first, or reset the (still empty of real data) databases and seed only reference data.

- [ ] The ROCBN registry answers (needs firewall row 12 and the account from section A). Read-only: it prints the account's privileges and warns if it holds more than `SELECT`:

  ```bash
  cd /opt/dofi
  docker compose run --rm --no-deps api bin/rails rocbn:check       # exit 0, "privileges  SELECT only"
  ```

  Nothing else depends on it: if the registry is down the API keeps serving, and only the company lookup answers `503`.

- [ ] nginx in front of the API (step 5):

  ```bash
  sudo cp /opt/dofi/nginx/dofi-api.conf /etc/nginx/sites-available/dofi-api
  sudo ln -sf /etc/nginx/sites-available/dofi-api /etc/nginx/sites-enabled/dofi-api
  sudo nginx -t && sudo systemctl reload nginx               # never skip the -t
  curl -i http://10.252.8.12:3000/up                         # 200 (this is nginx; 127.0.0.1:3000 is Rails itself)
  ```

- [x] Host firewall (step 6). This host runs `firewalld`, which rejects everything not listed. Allow only the frontend to 3000, without `--reload`:

  ```bash
  RULE='rule family="ipv4" source address="10.246.8.12" port port="3000" protocol="tcp" accept'
  sudo firewall-cmd --add-rich-rule="$RULE"
  sudo firewall-cmd --permanent --add-rich-rule="$RULE"
  ```

- [ ] From the frontend server (or any machine on the users' network), prove what a browser will meet (step 7):

  ```bash
  curl -i http://<BACKEND_IP>/up                             # 200

  # CORS preflight: expect 200 and `access-control-allow-origin: <FE_ORIGIN>`
  curl -i -X OPTIONS http://<BACKEND_IP>/api/v1/auth/sign_in \
    -H 'Origin: <FE_ORIGIN>' -H 'Access-Control-Request-Method: POST' \
    -H 'Access-Control-Request-Headers: content-type,authorization'

  # WebSocket handshake: expect `HTTP/1.1 101 Switching Protocols` (curl stops after 5 s; 404 = CABLE_ALLOWED_ORIGINS wrong)
  curl -i -N --max-time 5 http://<BACKEND_IP>/cable \
    -H 'Connection: Upgrade' -H 'Upgrade: websocket' -H 'Sec-WebSocket-Version: 13' \
    -H 'Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==' -H 'Origin: <FE_ORIGIN>'
  ```

## E. Release by hand (every update after the first run)

CI has already built the image; the server only pulls it. Run this in the Delinea terminal on the backend server.

- [ ] Merge to `main`, then wait until the workflow "CD Production" shows `Build & Push GHCR` green (Slack says "Manual deployment required").
- [ ] If the compose file changed in this release, paste the new `deploy/production/backend/docker-compose.yml` into `/opt/dofi/docker-compose.yml` first (nothing copies it for you), then `docker compose config -q`.
- [ ] Release:

  ```bash
  cd /opt/dofi
  docker compose pull
  docker compose run --rm api bin/rails db:prepare
  docker compose up -d --wait
  curl -fsS http://127.0.0.1:3000/up
  docker compose ps
  docker image prune -f
  ```

- [ ] Check the logs for 2 minutes: `docker compose logs --since 2m api jobs`.
- [ ] To run a specific build instead of the newest, set `IMAGE_TAG=<git sha>` in `/opt/dofi/.env` before `pull` (the same is how you roll back, section H).

## F. Verify the whole system

- [ ] Log in from the frontend (BruneiID or the admin account).
- [ ] The seeded admin `admin@dofi.gov.bn` exists: **change its password immediately**.
- [ ] Upload a file (a company document or vessel image), then open it; the browser must be able to reach `http://<STORAGE_IP>:9000`.
- [ ] No CORS error in the browser console; a WebSocket (notifications) connects.
- [ ] Logs are clean (on the backend server):

  ```bash
  cd /opt/dofi && docker compose logs --tail 100 api jobs
  sudo tail -n 50 /var/log/nginx/error.log
  ```

- [ ] Give the frontend team the API URL `http://<BACKEND_IP>:3000` and the WebSocket URL `ws://<BACKEND_IP>:3000/cable`.

## G. Backups (minimum)

On the database server, replacing nothing (the database name is `dofi_backend_production`). Details: [database runbook, step 6](../../deploy/production/database/README.md#6-backups-minimum-before-go-live).

- [ ] Install the nightly `pg_dump` cron job (14-day retention in `/var/backups/dofi`):

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
  sudo -u postgres /usr/local/bin/dofi-backup && ls -l /var/backups/dofi     # run it once now to prove it works
  ```

- [ ] Copy the dumps to a place the client controls.
- [ ] Do one restore into a scratch database before go-live:

  ```bash
  sudo -u postgres createdb dofi_restore_test
  sudo -u postgres pg_restore -d dofi_restore_test --clean --if-exists /var/backups/dofi/primary-<date>.dump
  sudo -u postgres dropdb dofi_restore_test
  ```

## H. Operate, rollback and troubleshooting

On the backend server:

```bash
cd /opt/dofi
docker compose logs -f --tail 100 api jobs                   # app logs
docker compose up -d                                         # after editing .env: recreates only what changed
sudo nginx -t && sudo systemctl reload nginx                 # after editing the vhost
```

**Roll back the backend:** edit `/opt/dofi/.env`, set `IMAGE_TAG=<previous git sha>`, run `docker compose up -d`. Database migrations are **not** rolled back, so keep migrations compatible with the previous release.

| Symptom | Likely cause and fix |
|---|---|
| `docker compose pull` says `unauthorized` | The `read:packages` token from B expired or was revoked: make a new one and repeat the `docker login` (C3). |
| `docker compose pull` says the tag is not found | CI did not push it: check the `Build & Push GHCR` job on the commit, or use section J. |
| `docker compose` says `.env` is missing | Create `/opt/dofi/.env` on the backend server (C3). |
| `502 Bad Gateway` from the backend's nginx | `api` is down or still booting: `docker compose ps` and `logs api`, then `curl http://127.0.0.1:3000/up` on the server. More in [the backend runbook](../../deploy/production/backend/README.md#9-troubleshooting). |
| `db:prepare` cannot connect | Wrong `DATABASE_HOST`/`DATABASE_PORT`/password, or the client's firewall blocks `5432` from the backend. |
| The company lookup answers `503`, or `rocbn:check` fails | Run `docker compose run --rm --no-deps api bin/rails rocbn:check`. Connection refused or a timeout: firewall row 12, or a wrong `ROCBN_DB_HOST`/`ROCBN_DB_PORT`. `Access denied`: wrong account or password, or the account is not allowed from `10.252.8.12`. An authentication plugin error: ask the DBA which plugin the account uses. `lacks: <column>`: the registry's table changed; tell the backend team. [More](../rocbn/company-lookup.md#troubleshooting). |
| `db:prepare` fails while seeding images | MinIO not running, or the keys in the backend `.env` do not match the storage `.env`; run C2 and `mc-init` first. |
| Browser CORS error | Frontend origin missing in `CORS_ORIGINS` / `CABLE_ALLOWED_ORIGINS`; edit `.env`, `docker compose up -d`. |
| File links `403 SignatureDoesNotMatch` | `MINIO_PUBLIC_ENDPOINT` differs from the address the browser actually uses. |
| Login loops or redirects to HTTPS | `FORCE_SSL` must be `false` while there is no certificate. |

## I. Not done yet

- A domain and certificates: HTTPS on the backend's nginx ([runbook, step 10](../../deploy/production/backend/README.md#10-later-a-domain-and-tls)), a proxy in front of MinIO, then `FORCE_SSL=true`.
- A second `api` replica for zero-downtime releases; TLS between servers.
- Off-host backups with a schedule and a tested restore.
- Remove the old root `docker-compose.production.yml` once the old production server is retired (staging and local still use `docker/mc-init.sh`).

## J. Fallback: build on the server (only if CI or ghcr.io is down)

For an urgent fix when no image can be pulled. Needs the fallback part of the whitelist (section A). Full explanation:
[backend runbook, section 11](../../deploy/production/backend/README.md#11-fallback-build-on-the-server-approach-b).

- [ ] One time, as the deploy user on the backend server: a read-only GitHub **deploy key** and an SSH config that reaches GitHub on port 443, then clone the repo (replace nothing; the key is added in the repo's Settings, Deploy keys, without write access):

  ```bash
  ssh-keygen -t ed25519 -f ~/.ssh/dofi_github_readonly -N ""
  cat ~/.ssh/dofi_github_readonly.pub          # add this line as a Deploy key in the GitHub repo
  nano ~/.ssh/config                           # paste the Host block below, then: chmod 600 ~/.ssh/config
  ssh -T git@github.com                        # "successfully authenticated"
  git clone git@github.com:arya020595/st_dofi_backend.git /opt/dofi/src
  cp /opt/dofi/src/deploy/production/backend/docker-compose.build.yml /opt/dofi/
  ```

  ```
  Host github.com
    HostName ssh.github.com
    Port 443
    User git
    IdentityFile ~/.ssh/dofi_github_readonly
    IdentitiesOnly yes
  ```

- [ ] Each fallback release (both `-f` files every time, or Compose returns to the GHCR image):

  ```bash
  cd /opt/dofi/src && git pull --ff-only && git log -1 --oneline
  cd /opt/dofi
  docker compose -f docker-compose.yml -f docker-compose.build.yml build
  docker compose -f docker-compose.yml -f docker-compose.build.yml run --rm api bin/rails db:prepare
  docker compose -f docker-compose.yml -f docker-compose.build.yml up -d --wait
  curl -fsS http://127.0.0.1:3000/up
  ```

- [ ] Back to normal releases once CI works again: `docker compose pull && docker compose up -d` (without the override).
