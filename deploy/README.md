# deploy/: production on the client's servers

One `docker-compose.yml` per server, reached by IP over plain HTTP (no domain, no TLS yet). The backend server has nginx on port 3000 (the port the client's firewall opens to the frontend) in front of Rails.
Design and what comes later: [`docs/architecture/production-4-server-architecture.md`](../docs/architecture/production-4-server-architecture.md).
The backend CD (`cd-production.yml`) deploys this layout once the servers are prepared: follow [the checklist](../docs/ci-cd/PRODUCTION-DEPLOY-CHECKLIST.md) first.

| Folder | Server | Runs |
|---|---|---|
| [`production/database/`](production/database/README.md) | database | PostgreSQL 16, native (apt), no Docker |
| [`production/storage/`](production/storage/) | file storage | MinIO |
| [`production/backend/`](production/backend/README.md) | backend | nginx (host, port 3000), Rails `api` and `jobs` |

## On every server, once

On the **backend and storage** servers: install Docker Engine with the Compose plugin (the backend also needs nginx from apt), and `docker login ghcr.io` with a read-only token (those images are private). The **database** server needs no Docker: it runs PostgreSQL natively. Install git only if you prefer to `git clone` this repo instead of copying files.

## Deploy (in this order: database, storage, backend)

On the storage and backend servers: copy the files below to `/opt/dofi`, then `cd /opt/dofi && cp .env.example .env`, fill in `.env`
(generate secrets with `openssl rand -hex 32`), and run the start command. The database server follows its own runbook.

| Server | Copy | Start |
|---|---|---|
| Database | nothing to copy | follow [`production/database/README.md`](production/database/README.md) (`apt install postgresql-16`, role, `pg_hba.conf`) |
| Storage | `production/storage/docker-compose.yml`, `.env.example`, and `docker/mc-init.sh` | `docker compose up -d --wait && docker compose run --rm mc-init` |
| Backend | `production/backend/docker-compose.yml`, `.env.example`, and `nginx/dofi-api.conf` | follow [`production/backend/README.md`](production/backend/README.md): `docker compose pull && docker compose run --rm api bin/rails db:prepare && docker compose up -d`, then the nginx vhost |

Example upload: `scp deploy/production/storage/docker-compose.yml deploy/production/storage/.env.example <server>:/opt/dofi/`.

Values that travel between servers:
- The password you give the `dofi` role on the database server (runbook step 3) is the backend's `DATABASE_PASSWORD`; the database server's IP is `DATABASE_HOST`, and the port is `5432`.
- Storage `.env` bucket names and access keys are copied into the backend `.env`; the storage server's IP goes into `MINIO_ENDPOINT` and `MINIO_PUBLIC_ENDPOINT`.
- The frontend's address goes into the backend's `CORS_ORIGINS` and `CABLE_ALLOWED_ORIGINS`.

The order matters: the first `db:prepare` creates the four databases and seeds reference data including images,
so the database and MinIO (with `mc-init` done) must already be running. Check it works: `curl http://<backend-ip>:3000/up` from the frontend server (that is nginx; Rails itself answers only on the server's loopback).

## Things to know

- Ports 80 (backend nginx) and 9000 (storage) are open to the network, because browsers and servers reach them directly. Rails on the backend is published on `127.0.0.1:3000` only, so port 3000 stays closed. The database (5432) listens on the server's private IP only, and `pg_hba.conf` plus `ufw` (and the client's network firewall) allow only the backend server. Docker-published ports bypass `ufw`, which matters for MinIO but not for the native database.
- Nothing here is backed up. Minimum for the database: the nightly `pg_dump` cron job in [the database runbook](production/database/README.md#6-backups-minimum-before-go-live), copied off the server.
- Without TLS, passwords and tokens cross the network in clear. Adding a domain and certificates is the first follow-up.

## CI/CD for the backend

[`cd-production.yml`](../.github/workflows/cd-production.yml) tests the code and pushes the image to `ghcr.io` on every push
to `main`. It does **not** deploy: GitHub cannot reach the client's network, so an engineer pulls the image on the backend
server through Delinea (`docker compose pull`, `run --rm api bin/rails db:prepare`, `up -d`). The compose file, `.env` and the
nginx vhost are updated by hand. If CI or `ghcr.io` is down, [`production/backend/docker-compose.build.yml`](production/backend/docker-compose.build.yml)
builds the image on the server instead. The database and storage servers are never deployed by CI. Step-by-step setup, secrets and rollback:
[`docs/ci-cd/PRODUCTION-DEPLOY-CHECKLIST.md`](../docs/ci-cd/PRODUCTION-DEPLOY-CHECKLIST.md).
