# DoFi Backend (FINS — Capture Fisheries Module)

API-only Rails backend for the FINS Capture Fisheries module: vessels, crews, manifests, capture reports, and related reference data.

## Stack

- Ruby 3.4.7 / Rails 8.1.3 (API-only)
- PostgreSQL
- Solid Queue / Solid Cache (DB-backed, no Redis)
- Devise + devise-jwt for authentication, Pundit for authorization
- dry-monads for the service layer, Blueprinter for serialization
- Pagy + Ransack for pagination/search, Audited + Discard for audit trail/soft delete
- MinIO (S3-compatible) for file storage, Sentry + Lograge for monitoring/logging

## Cross-platform line endings

This repo's `.gitattributes` and `.editorconfig`/`.vscode` settings are the source of truth for
line endings — they force LF on `bin/*` and other text files on checkout, regardless of your OS
or Git config (notably Windows' common `core.autocrlf=true` default). This matters because the
dev Docker workflow bind-mounts the repo and execs `bin/*` scripts directly — a CRLF shebang
breaks with `env: 'ruby\r': No such file or directory`.

- New clones just work — nothing to configure, no `dos2unix`, no VS Code settings to change.
- An existing local clone that predates `.gitattributes` needs a one-time
  `git add --renormalize .` (or a fresh clone) to fix already-checked-out files.
- If you forget and run `docker compose up` anyway, the container fails fast on start with the
  exact fix to run, instead of the opaque shebang error above.

## Option A: Run with Docker (recommended)

Requires Docker and Docker Compose. No local Ruby/PostgreSQL installation needed.

1. Copy the env file and fill in any secrets you need (MinIO, Sentry, BruneiID, etc.):

   ```bash
   cp .env.example .env
   ```

2. Build and start the stack (API + Solid Queue worker + PostgreSQL):

   ```bash
   docker compose up --build
   ```

3. The `api` container runs `bin/rails db:prepare` automatically on every start, so the database
   is ready as soon as `docker compose up` finishes. Seed reference data once:

   ```bash
   docker compose exec api bin/rails db:seed
   ```

4. The API is available at `http://localhost:3000`. Health check: `http://localhost:3000/up`.

Useful commands:

```bash
docker compose exec api bundle install          # Install/update gems after a Gemfile change
docker compose exec api bin/rails console       # Rails console
docker compose exec api bin/rails test          # Run the test suite
docker compose exec api bin/rails db:migrate    # Run migrations
docker compose logs -f api jobs                 # Tail logs
docker compose down                             # Stop the stack
```

Source code is bind-mounted into the `api`/`jobs` containers, so local edits are picked up without rebuilding. If you only added/bumped a gem, `docker compose exec api bundle install` is usually enough and is faster than a rebuild. Rebuild the image when `Dockerfile.dev` itself changes, or if `bundle install` inside the container doesn't pick up the change:

```bash
docker compose up --build
```

### Production-style image (local test only)

`docker-compose.production.local.yml` builds the production image (`Dockerfile.production`) and expects a `.env.production` file plus `RAILS_MASTER_KEY` (from `config/master.key`) to decrypt credentials. This is for testing the production image locally — it is not deployed anywhere:

```bash
docker compose -f docker-compose.production.local.yml up --build
```

### Deployment (staging)

`develop` auto-deploys to staging via `.github/workflows/cd-staging.yml`, which copies `docker-compose.staging.yml` to the server and renames it to `docker-compose.yml` there (so `docker compose` picks it up by default — no `-f` flag needed for ad-hoc commands run directly on the server), then runs it against a `.env` that already lives there (not managed by CI). If a frontend gets a browser CORS error calling the staging API (no `Access-Control-Allow-Origin` on the response), that frontend's origin is missing from `CORS_ORIGINS` in the server's `.env` — add it (see `.env.example`) and restart the `api` container; `rack-cors` only reads this at boot.

### Deployment (production — 3 dedicated servers)

Production runs on 3 separate government-provided servers instead of one shared host: a backend server (api + jobs + MinIO), a database server, and a frontend server (a separate repo, not part of this one).

`main` auto-deploys to the backend server via `.github/workflows/cd-production.yml`, which copies `docker-compose.production.yml` (no `db:` service — only `api`, `jobs`, `minio`) and deploys the same way staging does. The deploy job is gated behind a GitHub `production` Environment with required reviewers (configured under repo Settings → Environments) — a human approves before the SSH deploy step runs.

The backend server's `.env` must point `DATABASE_HOST`/`DATABASE_PORT` at the separate database server (see `.env.example`), and `CORS_ORIGINS` at the frontend server's real origin. The database server itself just needs PostgreSQL 16 running, with `pg_hba.conf` restricted to the backend server's IP and TLS required — it is not managed by this repo's CI/CD.

File storage on both staging and production is self-hosted MinIO rather than Cloudinary, split across **two buckets with different access models** — a private bucket (no anonymous access, downloads via presigned URL) and a public-read bucket (anonymous `GetObject` only, e.g. `Dictionary` images) — see `docs/MINIO.md` §2 for the full rationale and `config/storage.yml`/the `MINIO_*` keys in `.env.example` for the config. Cloudinary is kept temporarily as a legacy service so existing attachments keep resolving during the cutover; run `bin/rails dictionaries:migrate_images_to_minio` (add `DRY_RUN=1` to preview) to copy existing `Dictionary` images onto MinIO before removing the `cloudinary` gem and its config.

## Option B: Run manually with Rails

Requires locally installed:

- Ruby 3.4.7 (see `.ruby-version`; a version manager such as `rbenv`/`asdf`/`mise` is recommended)
- PostgreSQL
- `libpq`, `libvips` (native deps for `pg` and `image_processing`)

1. Install dependencies:

   ```bash
   bundle install
   ```

2. Configure environment variables:

   ```bash
   cp .env.example .env
   # edit .env with your local DB credentials and any third-party keys
   ```

3. Create and migrate the database, then seed reference data:

   ```bash
   bin/rails db:prepare
   bin/rails db:seed
   ```

   Or simply run `bin/setup`, which installs gems, prepares the database, and starts the server in one step.

4. Start the app:

   ```bash
   bin/dev
   ```

   This starts the Rails server on `http://localhost:3000`.

5. Start the background job worker (Solid Queue) in a separate terminal:

   ```bash
   bin/jobs
   ```

## Common commands

Run these with `bin/rails`/`bundle` directly (Option B), or prefix with `docker compose exec api` (Option A).

### Gems

```bash
bundle install              # install/update gems from Gemfile.lock
bundle update <gem>         # bump a single gem
bundle exec <command>       # run any command in the bundle context (rarely needed; bin/rails already does this)
```

### Database & migrations

```bash
bin/rails db:prepare                    # create db (if needed) + run pending migrations
bin/rails db:migrate                    # run pending migrations
bin/rails db:rollback                   # undo the last migration
bin/rails db:rollback STEP=3            # undo the last 3 migrations
bin/rails db:migrate:status             # show which migrations have run
bin/rails db:reset                      # drop, recreate, migrate, and seed
bin/rails generate migration AddFooToBars foo:string   # create a new migration in db/migrate
```

### Resetting & reseeding the database

`bin/rails db:reset` drops, recreates, migrates, and seeds in one step (Option B, or Option A once the caveat below is handled). If you only want to wipe and reload seed data without touching the schema, use `db:seed:replant` instead (see [Seeding](#seeding)).

Under Docker (Option A), the `jobs` container (Solid Queue worker) keeps a connection open to the `*_queue` database, which makes `db:drop`/`db:reset` fail with `PG::ObjectInUse: database "..._queue" is being accessed by other users`. Stop it first, then restart it after reseeding:

```bash
docker compose stop jobs
docker compose exec api bin/rails db:reset      # or: db:drop db:create db:migrate db:seed
docker compose start jobs
```

### Seeding

```bash
bin/rails db:seed                       # load db/seeds.rb (idempotent, safe to re-run)
bin/rails db:seed:replant                # truncate seed-relevant tables, then reseed
RAILS_ENV=test bin/rails db:seed:replant # reseed the test database (what bin/ci runs)
```

Seed files live in `db/seeds/*.rb` and are loaded by `db/seeds.rb`; add a new seed module there and append it to `SEED_FILES`.

### Rake / custom tasks

```bash
bin/rails -T                            # list all available rake tasks
bin/rails <namespace>:<task>            # run a specific task, e.g. bin/rails solid_queue:start
bin/rails generate task <namespace> <task1> <task2>   # scaffold a new rake task under lib/tasks
```

### Console & misc generators

```bash
bin/rails console                       # interactive Rails console
bin/rails runner "SomeClass.do_thing"   # run a one-off snippet in app context
bin/rails generate model Foo bar:string # generate a model + migration
bin/rails generate controller foos      # generate a controller
bin/rails routes                        # print all routes
```

## Running tests

```bash
bin/rails test
```

## Full CI check (style, security, tests)

```bash
bin/ci
```

Runs, in order: `bin/setup`, `bin/rubocop`, `bin/bundler-audit`, `bin/brakeman`, `bin/rails test`, and a test-environment seed replay.

## Code style

See [CLAUDE.md](CLAUDE.md) for the architectural and coding conventions (SOLID principles, layering, naming) followed in this codebase.

## API documentation

- [Search, filter, sort & pagination contract](docs/api/search-filter-sort-pagination.md) — how the frontend should call list (`index`) endpoints (Ransack query params + Pagy pagination).
- [Postman collection](postman/DoFi-Backend.postman_collection.json)

## Infrastructure documentation

- [MinIO guide](docs/MINIO.md) — architecture and flow diagrams, how it's used and implemented, setup/start/stop for local, staging, and production, and the Cloudinary migration/cutover checklist.
- [MinIO two-bucket migration runbook](docs/MINIO-TWO-BUCKET-SETUP.md) — what changed moving to the public/private bucket split, and step-by-step instructions to test it locally against real MinIO and roll it out to staging/production.
- [MinIO staging test report (2026-07-28)](docs/MINIO-STAGING-TEST-REPORT-2026-07-28.md) — real test results against the staging server, two bugs found and fixed (stale container env, missing `s3:ListBucket` breaking image deletes), and a self-test guide for staging/production.
- [MinIO public proxy setup tutorial](docs/MINIO-PUBLIC-PROXY-SETUP.md) — step-by-step guide for making MinIO URLs (both the private bucket's presigned and the public bucket's plain) reachable from a browser (host nginx or Docker-only options), including the `$host` vs `$http_host` pitfall.
- [MinIO presigned URL postmortem (2026-07-27)](docs/POSTMORTEM-2026-07-27-minio-presigned-url.md) — incident writeup for `image_url` pointing at MinIO's internal Docker address instead of a public one.
- [CI/CD setup guide](docs/CI-CD-SETUP.md) — how the GitHub Actions workflows and Docker Compose deploy files fit together.
