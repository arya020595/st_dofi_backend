# CI/CD Setup Guide

A step-by-step guide for setting up Docker + GitHub Actions CI/CD for a service, deploying to a
staging server over SSH. Written generally so it applies to any new service, with this repo
(`st_dofi_backend`, a Rails API) used as the worked example throughout.

If you're setting up CI/CD for **this** repo, you're done — `Dockerfile.production`,
`docker-compose.staging.yml`, `.github/workflows/ci.yml` and `cd-staging.yml` already implement everything
below. Use this doc to understand *why* they're structured that way, or as a template for a new
service.

## Overview

```
Developer pushes code
        │
        ▼
┌─────────────────┐     pull_request / push      ┌──────────────────────┐
│   CI workflow    │ ────────────────────────────▶│  Run tests + lint    │
│  (every branch)  │                              │  Build image (no push)│
└─────────────────┘                              └──────────────────────┘

        │ push to develop
        ▼
┌─────────────────┐                              ┌──────────────────────┐
│   CD workflow    │ ── test ──▶ build-and-push ──▶│  Push image to GHCR  │
└─────────────────┘                              └──────────────────────┘
                                                            │
                                                            ▼
                                                  ┌──────────────────────┐
                                                  │  SSH to server        │
                                                  │  docker compose pull  │
                                                  │  run migrations        │
                                                  │  docker compose up -d  │
                                                  └──────────────────────┘
```

Two workflows, two concerns:

- **CI** (`ci.yml`) — runs on every PR and push to the protected branches. Tests, lints, security
  scans, and a build-only Docker check. Never pushes an image or touches the server.
- **CD** (`cd-staging.yml`) — runs only on push to `develop` (or whichever branch maps to staging). Re-runs
  the test suite as a gate, then builds, pushes, and deploys.

Running tests again in CD (instead of trusting a prior CI run) means CD is self-contained and
can't deploy a broken commit just because CI was skipped or flaky on an earlier push.

---

## Part 1 — Dockerize the App

### 1.1 — Dockerfile

Use a multi-stage build: one stage to install build tooling and compile dependencies, a slim
final stage that only contains runtime artifacts. This keeps the production image small and
avoids shipping compilers/headers to the server.

This repo's [Dockerfile.production](../Dockerfile.production) does this in three stages:

1. `base` — runtime OS packages only (e.g. `libpq-dev` client, `libvips`).
2. `build` — adds build tooling (`build-essential`, `git`, dev headers), installs dependencies,
   precompiles what can be precompiled ahead of time.
3. final stage — copies only the installed dependencies and app code from `build`, runs as a
   **non-root user**, and declares `EXPOSE`/`CMD`.

General checklist regardless of language/framework:

- [ ] Pin the runtime version with a build arg (`ARG RUBY_VERSION=3.4.7`) so it's obvious what to
      bump when the language version changes.
- [ ] Separate "things needed to build" from "things needed to run." Don't install compilers in
      the final image.
- [ ] Run the process as a non-root user (`USER 1000:1000`), not root.
- [ ] Add an entrypoint script for one-time startup work (e.g. this repo's
      `bin/docker-entrypoint` preps the database) — keep it idempotent since it runs on every
      container start.
- [ ] `EXPOSE` the port the app actually listens on, and make sure `CMD` binds to `0.0.0.0`, not
      `127.0.0.1` (otherwise it's unreachable from outside the container).

### 1.2 — `.dockerignore`

Exclude anything that shouldn't be baked into the image or that would invalidate the build cache
unnecessarily: `.git`, `.env*`, local credentials/key files, logs, tmp files, and the Dockerfiles
themselves. See [.dockerignore](../.dockerignore) for the full list used here — notably it
excludes `config/master.key` and `/config/deploy*.yml` (Kamal), since secrets must never be baked
into an image layer.

### 1.3 — `.env.example`

Commit an `.env.example` listing every environment variable the app needs, with blank or
placeholder values — **never real secrets**. This is the contract for what must exist in the
real `.env` on the server. See [.env.example](../.env.example).

```bash
cp .env.example .env   # then fill in real values, locally or on the server
```

### 1.4 — docker-compose files

It's worth having **two** compose files with distinct jobs, rather than one file with profiles/
overrides for every environment:

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Local development. Builds the image from source, mounts the code as a volume for live reload, exposes the DB port to the host for inspection. |
| `docker-compose.staging.yml` | Server deployment. Pulls a prebuilt image from the registry (never builds on the server), no source volume mounts, named volumes for persistent data. |

This repo's [docker-compose.staging.yml](../docker-compose.staging.yml) is the one CD copies to the
server. Points worth copying for any new service:

- `image: ghcr.io/<owner>/<repo>:staging` — pulls, never builds, on the server.
- `depends_on: db: condition: service_healthy` plus a `healthcheck:` on the db service — without
  this, the app can boot before Postgres is accepting connections and crash-loop.
- A separate service for background workers (`jobs:` here, running `solid_queue:start`) sharing
  the same image but a different `command:` — don't run worker processes inside the web
  container.
- Named volumes (`dofi_staging_postgres_data`, `dofi_staging_storage`) so data survives
  `docker compose up -d --force-recreate`.
- `env_file: .env` for secrets, plus a few non-secret `environment:` overrides — keeps the bulk
  of config out of the compose file itself.

---

## Part 2 — Server Folder Setup

SSH into the server and create a dedicated folder per service — don't share one folder between
unrelated services.

```bash
ssh <user>@<server-ip>

sudo mkdir -p /opt/<service-name>
sudo chown <user>:<user> /opt/<service-name>
```

> Naming tip: match the folder name to the repo/image name so it's unambiguous which service it
> is six months from now (e.g. `/home/stadmin/st_dofi_backend_staging` for this repo).

### Create the `.env` file on the server

This holds all real secrets. **Never commit this to git** — it only ever exists on the server
(and in each developer's local checkout, gitignored).

```bash
nano /opt/<service-name>/.env
```

Fill it in using `.env.example` from the repo as the checklist of required keys.

> Each service on a shared server must use **different host ports**. Check what's already bound
> before picking one:
> ```bash
> docker ps --format "table {{.Names}}\t{{.Ports}}"
> ```

---

## Part 3 — GitHub Actions Secrets

Go to the repository → **Settings → Secrets and variables → Actions → New repository secret**.

| Secret name | Value |
|--------------|-------|
| `STAGING_SSH_HOST` | Server IP or hostname |
| `STAGING_SSH_USER` | SSH user (e.g. `deploy`, `stadmin`) |
| `STAGING_SSH_PORT` | Usually `22` |
| `STAGING_SSH_KEY` | Private SSH key (see below) |
| `SLACK_WEBHOOK_URL` | Slack incoming webhook URL *(optional, for build/deploy notifications)* |

`GITHUB_TOKEN` is provided automatically by Actions for pushing to GHCR — no need to add it as a
secret.

### Setting up the SSH key

**Check with the server admin first** — if a deploy key has already been issued for this server,
reuse it instead of generating a new one. Only generate a new key if you've been told to.

If you do need a new key, generate it on your local machine (not the server):

```bash
ssh-keygen -t ed25519 -C "github-actions-<service-name>" -f ~/.ssh/<service-name>_deploy -N ""
```

Add the **public** key to the server:

```bash
ssh-copy-id -i ~/.ssh/<service-name>_deploy.pub <user>@<server-ip>
```

Copy the **private** key into the `STAGING_SSH_KEY` GitHub secret:

```bash
cat ~/.ssh/<service-name>_deploy
# copy the entire output, including the -----BEGIN and -----END lines
```

---

## Part 4 — CI Workflow (every PR / push)

Create `.github/workflows/ci.yml`. Runs on pull requests and pushes to the protected branches.
Its job is to catch problems **before** merge — it never pushes an image or touches the server.

```yaml
name: CI

on:
  pull_request:
    branches: [develop, main]
  push:
    branches: [develop, main]

concurrency:
  group: ci-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: postgres
        ports:
          - 5432:5432
        options: >-
          --health-cmd "pg_isready -U postgres"
          --health-interval 5s
          --health-timeout 5s
          --health-retries 10

    env:
      DATABASE_HOST: localhost
      DATABASE_PORT: 5432
      # ...any other env vars the test suite needs (use throwaway values, never real secrets)

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up runtime
        uses: ruby/setup-ruby@v1   # swap for setup-node, setup-python, etc.
        with:
          bundler-cache: true

      - name: Install system dependencies
        run: sudo apt-get update -qq && sudo apt-get install -y --no-install-recommends libpq-dev

      - name: Run lint, security scans, and tests
        run: bin/ci   # or your project's equivalent single entrypoint

  docker-build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build production image (no push)
        uses: docker/build-push-action@v5
        with:
          context: .
          file: Dockerfile.production
          push: false
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

Key choices worth keeping for any service:

- `concurrency` with `cancel-in-progress: true` — a new push to the same PR cancels the
  in-flight run instead of queuing behind it, so CI reflects the latest commit.
- A single `bin/ci`-style script (lint + security scan + tests in one command) — keeps the
  workflow file thin and lets developers run the exact same check locally.
- `docker-build` is a **separate job** from `test`, so a slow Docker layer cache doesn't block
  test feedback, and a flaky Docker build doesn't get conflated with a real test failure.

This repo's actual file is [.github/workflows/ci.yml](../.github/workflows/ci.yml).

---

## Part 5 — CD Workflow (build, push, deploy)

Create `.github/workflows/cd-staging.yml`. Runs only on push to the branch that maps to staging
(`develop` here).

```yaml
name: CD

on:
  push:
    branches: [develop]

concurrency:
  group: cd-staging
  cancel-in-progress: false   # never cancel a deploy mid-flight

jobs:
  test:
    runs-on: ubuntu-latest
    # ... same test job as CI — see Part 4.
    # CD re-runs tests rather than trusting a prior CI run, so it can't deploy a commit
    # that never actually passed CI (e.g. a direct push, or a rebase after CI ran).

  build-and-push:
    needs: test
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Set lowercase image name
        id: image
        run: |
          OWNER=$(echo "${{ github.repository_owner }}" | tr '[:upper:]' '[:lower:]')
          echo "name=ghcr.io/${OWNER}/<service-name>" >> "$GITHUB_OUTPUT"

      - name: Build and push image
        uses: docker/build-push-action@v5
        with:
          context: .
          file: Dockerfile.production
          push: true
          tags: |
            ${{ steps.image.outputs.name }}:${{ github.sha }}
            ${{ steps.image.outputs.name }}:staging
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Notify Slack — build result
        if: always() && env.SLACK_WEBHOOK_URL != ''
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
        run: |
          STATUS="${{ job.status }}"
          if [ "$STATUS" = "success" ]; then COLOR="good"; ICON=":white_check_mark:"; TEXT="*Build passed* — image pushed to GHCR."; else COLOR="danger"; ICON=":x:"; TEXT="*Build failed* — image was NOT pushed."; fi
          curl -s -X POST "$SLACK_WEBHOOK_URL" \
            -H 'Content-type: application/json' \
            --data "{\"attachments\":[{\"color\":\"$COLOR\",\"text\":\"$ICON $TEXT\"}]}"

  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: read

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Copy docker-compose.staging.yml to server
        uses: appleboy/scp-action@v0.1.7
        with:
          host: ${{ secrets.STAGING_SSH_HOST }}
          username: ${{ secrets.STAGING_SSH_USER }}
          port: ${{ secrets.STAGING_SSH_PORT }}
          key: ${{ secrets.STAGING_SSH_KEY }}
          source: docker-compose.staging.yml
          target: /opt/<service-name>

      - name: Deploy on server
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.STAGING_SSH_HOST }}
          username: ${{ secrets.STAGING_SSH_USER }}
          port: ${{ secrets.STAGING_SSH_PORT }}
          key: ${{ secrets.STAGING_SSH_KEY }}
          script: |
            cd /opt/<service-name>
            echo ${{ secrets.GITHUB_TOKEN }} | docker login ghcr.io -u ${{ github.actor }} --password-stdin
            docker compose -f docker-compose.staging.yml pull
            docker compose -f docker-compose.staging.yml run --rm api bin/rails db:prepare
            docker compose -f docker-compose.staging.yml up -d
            docker image prune -f

      - name: Notify Slack — deploy result
        if: always() && env.SLACK_WEBHOOK_URL != ''
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
        run: |
          STATUS="${{ job.status }}"
          if [ "$STATUS" = "success" ]; then COLOR="good"; ICON=":rocket:"; TEXT="*Deploy succeeded* — staging is live."; else COLOR="danger"; ICON=":fire:"; TEXT="*Deploy failed* — staging was NOT updated."; fi
          curl -s -X POST "$SLACK_WEBHOOK_URL" \
            -H 'Content-type: application/json' \
            --data "{\"attachments\":[{\"color\":\"$COLOR\",\"text\":\"$ICON $TEXT\"}]}"
```

### What happens on every push to `develop`

```
1. test
   └─ Same suite as CI — acts as a gate before anything is built or pushed.

2. build-and-push   (only if test passed)
   ├─ Builds the production image
   ├─ Tags it with the commit SHA and "staging"
   ├─ Pushes both tags to GHCR
   └─ Notifies Slack (if configured)

3. deploy   (only if build-and-push passed)
   ├─ Copies docker-compose.staging.yml to the server
   ├─ SSHs in, pulls the new image
   ├─ Runs pending migrations (framework-dependent step)
   ├─ Restarts containers
   ├─ Prunes dangling images
   └─ Notifies Slack (if configured)
```

> For frameworks that need a migration step (Rails, Django, etc.), run it **before**
> `docker compose up -d`, against the new image, not the running container:
> ```yaml
> docker compose -f docker-compose.staging.yml run --rm api bin/rails db:prepare
> ```
> Running it as a one-off `run --rm` (rather than baking it into the entrypoint) keeps migration
> failures visible as a distinct, loud CD step instead of silently crash-looping the app
> container.

This repo's actual file is [.github/workflows/cd-staging.yml](../.github/workflows/cd-staging.yml).

> On the staging server specifically, the deploy step renames the copied file from
> `docker-compose.staging.yml` to `docker-compose.yml` before running any `docker compose`
> commands (`mv -f docker-compose.staging.yml docker-compose.yml`). This lets `docker compose`
> pick the file up by its default name, so anyone SSHing in to run ad-hoc commands doesn't need
> to remember a `-f <file>` flag. This is specific to this repo's staging server, not a required
> part of the general pattern above.

### Production is a second, near-identical CD workflow

This repo also has [.github/workflows/cd-production.yml](../.github/workflows/cd-production.yml), which
deploys to `main` instead of `develop`, tags images `:production` instead of `:staging`, and copies
[docker-compose.production.yml](../docker-compose.production.yml) instead of
`docker-compose.staging.yml`. Two differences worth calling out for any service that needs a real
production environment (not just staging) on separate infrastructure:

- **No `db:` service in the production compose file.** The production database runs on its own
  dedicated server, not co-located with the app. `DATABASE_HOST`/`DATABASE_PORT` in the backend
  server's `.env` point at that separate server instead of a Docker Compose service name — no
  code change needed if `config/database.yml` already reads these from `ENV`.
- **The `deploy` job is gated behind a GitHub `production` Environment** (Settings → Environments
  → New environment → add required reviewers). Unlike staging's push-to-deploy, a human approves
  the SSH deploy step before it runs — appropriate once "staging" becomes "a government client's
  real production system."

New secrets needed, parallel to the `STAGING_SSH_*` ones in Part 3:
`PRODUCTION_SSH_HOST`, `PRODUCTION_SSH_USER`, `PRODUCTION_SSH_PORT`, `PRODUCTION_SSH_KEY`. Database
and object-storage credentials are never GitHub secrets — they live only in the backend server's
own `.env`, same as every other secret in this guide.

---

## Part 6 — Verifying the Deployment

```bash
ssh <user>@<server-ip>
cd /opt/<service-name>

# All containers running and healthy?
docker compose -f docker-compose.staging.yml ps

# App responds?
curl http://localhost:<published-port>

# Any errors in the logs?
docker compose -f docker-compose.staging.yml logs api --tail=50
docker compose -f docker-compose.staging.yml logs jobs --tail=50
```

---

## Common Issues

| Problem | Likely Cause | Fix |
|---------|-------------|-----|
| `EADDRINUSE` / port already in use | Another service on the server uses the same host port | Pick a different port in `.env` / compose file; check with `docker ps --format "table {{.Names}}\t{{.Ports}}"` |
| `pull access denied` | Not logged in to GHCR on the server, or image is private and token lacks scope | `echo $TOKEN \| docker login ghcr.io -u <user> --password-stdin` |
| Container exits immediately | Bad or missing `.env` value | `docker compose logs <service>` to see the actual error |
| DB connection refused on first start | App container started before Postgres was ready | Add `depends_on: condition: service_healthy` + a `healthcheck:` on the db service |
| Migrations not applied after deploy | Migration step missing or running against the old container | Run migrations as a one-off `run --rm` against the freshly-pulled image, before `up -d` |
| `Permission denied` on SSH | Public key not installed on the server, or wrong user/port secret | `ssh-copy-id -i ~/.ssh/<key>.pub <user>@<server-ip>`; double-check `STAGING_SSH_*` secrets |
| Nginx/reverse-proxy `502 Bad Gateway` | App container not running or crashed | `docker compose ps` and `docker compose logs api` |
| Changes not showing after deploy | Old container still running with cached layers | `docker compose up -d --force-recreate` |
| CORS errors in the browser after deploy | New frontend origin not added to the API's allowlist | Add the origin to `CORS_ORIGINS` in the server's `.env`, restart the `api` container |
