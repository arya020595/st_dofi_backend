# DoFi Backend (FINS — Capture Fisheries Module)

API-only Rails backend for the FINS Capture Fisheries module: vessels, crews, manifests, capture reports, and related reference data.

## Stack

- Ruby 3.4.7 / Rails 8.1.3 (API-only)
- PostgreSQL
- Solid Queue / Solid Cache (DB-backed, no Redis)
- Devise + devise-jwt for authentication, Pundit for authorization
- dry-monads for the service layer, Blueprinter for serialization
- Pagy + Ransack for pagination/search, Audited + Discard for audit trail/soft delete
- Cloudinary for file storage, Sentry + Lograge for monitoring/logging

## Option A: Run with Docker (recommended)

Requires Docker and Docker Compose. No local Ruby/PostgreSQL installation needed.

1. Copy the env file and fill in any secrets you need (Cloudinary, Sentry, BruneiID, etc.):

   ```bash
   cp .env.example .env
   ```

2. Build and start the stack (API + Solid Queue worker + PostgreSQL):

   ```bash
   docker compose up --build
   ```

3. In another terminal, prepare the database (first run only):

   ```bash
   docker compose exec api bin/rails db:prepare
   docker compose exec api bin/rails db:seed
   ```

4. The API is available at `http://localhost:3000`. Health check: `http://localhost:3000/up`.

Useful commands:

```bash
docker compose exec api bin/rails console      # Rails console
docker compose exec api bin/rails test         # Run the test suite
docker compose exec api bin/rails db:migrate    # Run migrations
docker compose logs -f api jobs                 # Tail logs
docker compose down                             # Stop the stack
```

Source code is bind-mounted into the `api`/`jobs` containers, so local edits are picked up without rebuilding. Rebuild only when `Gemfile`/`Gemfile.lock` or `Dockerfile.dev` change:

```bash
docker compose up --build
```

### Production-style image

`docker-compose.production.yml` builds the production image (`Dockerfile.production`) and expects a `.env.production` file plus `RAILS_MASTER_KEY` (from `config/master.key`) to decrypt credentials:

```bash
docker compose -f docker-compose.production.yml up --build
```

### Deployment (staging)

`develop` auto-deploys to staging via `.github/workflows/cd.yml`, which copies `docker-compose.deploy.yml` to the server and runs it against a `.env` that already lives there (not managed by CI). If a frontend gets a browser CORS error calling the staging API (no `Access-Control-Allow-Origin` on the response), that frontend's origin is missing from `CORS_ORIGINS` in the server's `.env` — add it (see `.env.example`) and restart the `api` container; `rack-cors` only reads this at boot.

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
