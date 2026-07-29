# MinIO Two-Bucket Migration — What Changed, and How to Test/Deploy It

This is the practical companion to `docs/minio/MINIO.md` §2 ("Public vs private buckets") — that doc
explains the architecture and *why*; this one is the runbook: what changed in this migration, and
the exact steps to test it locally and roll it out to staging/production.

---

## 1. What changed (summary)

The app moved from **one MinIO bucket** to **two**, split by sensitivity (see `docs/minio/MINIO.md` §2
for the full rationale):

| | Private bucket (existing) | Public bucket (new) |
|---|---|---|
| Env vars | `MINIO_BUCKET`, `MINIO_ACCESS_KEY_ID`, `MINIO_SECRET_ACCESS_KEY` | `MINIO_ASSETS_BUCKET`, `MINIO_ASSETS_ACCESS_KEY_ID`, `MINIO_ASSETS_SECRET_ACCESS_KEY` |
| Anonymous access | None | `GetObject` only (never `ListBucket`) |
| Download path | `Api::V1::AttachmentsController` → `302` redirect to a presigned URL | Direct, unsigned URL straight in JSON — no redirect |
| Who uses it today | `CompaniesDocument#file` (company registration/licence PDFs) | `Dictionary#image` (fish-species reference photos) |

Also in this pass, an independent security/SOLID audit turned up and fixed:

- **`docker/mc-init.sh`** hardened against a documented MinIO `mc` CLI re-attach quirk
  (`mc admin policy attach` can exit 1 if already attached) — `|| true` added as cheap insurance.
  Tested directly against the pinned `mc` version: it did **not** actually reproduce, but the
  safeguard costs nothing and protects against a future regression.
- **`.github/workflows/cd-staging.yml`/`cd-production.yml`** now have `set -e` in the deploy
  script — previously a failed step (e.g. `mc-init`) wouldn't fail the GitHub Actions job at all,
  since the script kept running and the last command (`docker image prune -f`) almost always
  exits 0.
- **`Attachments::UploadFromParam`** extracted — `Dictionaries::Create`/`Update` had duplicated,
  security-relevant upload logic (magic-byte content-type detection) verbatim.
- **Test gaps closed**: `Attachments::PublicUrl`/`AssetUrl`'s service-selection branching (never
  exercised — the test suite only uses the Disk service) and Marcel content-type sniffing actually
  rejecting a mislabeled upload.
- **`config/brakeman.ignore` removed** — the one Brakeman "Redirect" warning is resolved by naming
  a private controller method `presigned_url` (ending in `_url`), which satisfies Brakeman's own
  documented exemption for URL-generator methods, instead of suppressing the warning.
- Three docs (`MINIO-PUBLIC-PROXY-SETUP.md`, the 2026-07-27 postmortem, `README.md`) updated —
  they predated the public-bucket work and still described `Dictionary` as using the presigned
  path it has since moved off of.

**A separate, earlier fix in this same session** (not part of the bucket split, but a hard
prerequisite before any of this touches staging/production): `active_storage_attachments.record_id`
was `bigint` while every other table in this app uses `uuid` — meaning `has_one_attached` could
resolve to the *wrong record's* file once more than one record had one attached. Fixed via migration
`20260728044630_fix_active_storage_attachments_record_id_type.rb`, which also purges any existing
(unrecoverably mislinked) attachments. **This has only been run locally so far** — see §4/§5.

---

## 2. Prerequisites (every environment)

Two credential pairs and two bucket names now exist per environment, not one:

```bash
openssl rand -hex 10    # -> MINIO_ACCESS_KEY_ID           (private, likely already set)
openssl rand -hex 20    # -> MINIO_SECRET_ACCESS_KEY        (private, likely already set)
openssl rand -hex 10    # -> MINIO_ASSETS_ACCESS_KEY_ID     (new)
openssl rand -hex 20    # -> MINIO_ASSETS_SECRET_ACCESS_KEY (new)
```

Use **two different key pairs** — reusing the private bucket's credential for the public bucket
defeats the entire point of the split (see `docs/minio/MINIO.md` §2, "credential separation").

Bucket names: recommended convention is `dofi-<env>-private` / `dofi-<env>-public` — e.g.
`MINIO_BUCKET=dofi-staging-private`, `MINIO_ASSETS_BUCKET=dofi-staging-public` (see `docs/minio/MINIO.md`
§2's naming note for why the env var stays `MINIO_ASSETS_*` even though the bucket itself is named
`-public`). If `MINIO_BUCKET` is already set to something else (e.g. a bare `dofi-staging` from
before this split existed), renaming it is safe as long as nothing has been deployed against the
new two-bucket `mc-init` yet — see §4 step 1 for the staging-specific case.

---

## 3. Local testing (against real MinIO, not just the test suite)

The Minitest suite only ever exercises the Disk service — it cannot catch anything specific to
real S3/MinIO behavior (bucket policies, anonymous access, SigV4). This is how to actually prove
it end-to-end, using `docker-compose.production.local.yml` (builds `Dockerfile.production` from
source; not deployed anywhere, local-only).

### 3.1 Set up throwaway env files

Both are gitignored (`/.env*`) — never commit them. Run from the repo root:

```bash
MINIO_ROOT_USER=$(openssl rand -hex 12)
MINIO_ROOT_PASSWORD=$(openssl rand -hex 24)
MINIO_ACCESS_KEY_ID=$(openssl rand -hex 10)
MINIO_SECRET_ACCESS_KEY=$(openssl rand -hex 20)
MINIO_ASSETS_ACCESS_KEY_ID=$(openssl rand -hex 10)
MINIO_ASSETS_SECRET_ACCESS_KEY=$(openssl rand -hex 20)
DEVISE_JWT_SECRET_KEY=$(openssl rand -hex 64)

# Compose-level interpolation (${VAR} in the YAML itself — db/minio/mc-init blocks)
cat > .env.docker-test <<EOF
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=postgres
DATABASE_NAME=dofi_backend_docker_test
MINIO_ROOT_USER=${MINIO_ROOT_USER}
MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}
MINIO_ACCESS_KEY_ID=${MINIO_ACCESS_KEY_ID}
MINIO_SECRET_ACCESS_KEY=${MINIO_SECRET_ACCESS_KEY}
MINIO_BUCKET=dofi-docker-test-private
MINIO_ASSETS_ACCESS_KEY_ID=${MINIO_ASSETS_ACCESS_KEY_ID}
MINIO_ASSETS_SECRET_ACCESS_KEY=${MINIO_ASSETS_SECRET_ACCESS_KEY}
MINIO_ASSETS_BUCKET=dofi-docker-test-public
EOF

# Container runtime env (env_file: .env.production for api/jobs — a different mechanism)
cat > .env.production <<EOF
RAILS_ENV=production
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=postgres
DATABASE_NAME=dofi_backend_docker_test
DEVISE_JWT_SECRET_KEY=${DEVISE_JWT_SECRET_KEY}
RAILS_MASTER_KEY=$(cat config/master.key)
MINIO_ENDPOINT=http://minio:9000
MINIO_ACCESS_KEY_ID=${MINIO_ACCESS_KEY_ID}
MINIO_SECRET_ACCESS_KEY=${MINIO_SECRET_ACCESS_KEY}
MINIO_REGION=us-east-1
MINIO_BUCKET=dofi-docker-test-private
MINIO_ASSETS_ACCESS_KEY_ID=${MINIO_ASSETS_ACCESS_KEY_ID}
MINIO_ASSETS_SECRET_ACCESS_KEY=${MINIO_ASSETS_SECRET_ACCESS_KEY}
MINIO_ASSETS_BUCKET=dofi-docker-test-public
EOF
```

> ⚠️ `RAILS_MASTER_KEY` is required — `RAILS_ENV=production` refuses to boot without a
> `secret_key_base` source. `config/master.key` (gitignored, already on your machine if you've run
> this repo before) supplies it directly, no `credentials:edit` needed.

> ⚠️ **Port 3000 collision**: if your regular dev stack (`docker-compose.yml`, the everyday `api`
> container) is already running, it's very likely already bound to host port 3000. Check with
> `docker ps`. If so, temporarily change `docker-compose.production.local.yml`'s `api` service
> `ports:` from `"3000:3000"` to e.g. `"3099:3000"` for this test, and **change it back
> afterward** — don't leave that edit committed.

### 3.2 Bring up db + minio, provision buckets

```bash
docker compose --env-file .env.docker-test -f docker-compose.production.local.yml up -d db minio

# wait for both healthy, then:
docker compose --env-file .env.docker-test -f docker-compose.production.local.yml run --rm mc-init
```

Expect: `Bucket created successfully` ×2, `Created policy` ×2, `Added user` ×2, `Access permission
for ... is set` — exit code 0.

**Run it a second time** — this is the actual regression check for the idempotency fix:

```bash
docker compose --env-file .env.docker-test -f docker-compose.production.local.yml run --rm mc-init
```

Must still exit 0. If it doesn't, something about your `mc` version has reintroduced the
re-attach quirk described in §1 — the `|| true` in `docker/mc-init.sh` should already cover it,
but worth knowing if it doesn't.

### 3.3 Verify bucket policies directly

```bash
docker compose --env-file .env.docker-test -f docker-compose.production.local.yml run --rm --entrypoint sh mc-init -c '
  mc alias set local "http://minio:9000" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null
  echo "--- private bucket (expect: private) ---"
  mc anonymous get local/dofi-docker-test-private
  echo "--- public bucket (expect: custom, GetObject only, no ListBucket) ---"
  mc anonymous get-json local/dofi-docker-test-public
  echo "--- each app credential should have exactly its own policy ---"
  mc admin policy entities local --user "$MINIO_ACCESS_KEY_ID"
  mc admin policy entities local --user "$MINIO_ASSETS_ACCESS_KEY_ID"
'
```

### 3.4 Migrate the database explicitly

> ⚠️ **Don't rely on `docker compose up -d api` alone to migrate.** `bin/docker-entrypoint`'s
> auto-`db:prepare` check has a bash argument-matching bug against the real 6-argument production
> CMD (`./bin/rails server -b 0.0.0.0 -p 3000`) and silently never fires. Run it explicitly:

```bash
docker compose --env-file .env.docker-test -f docker-compose.production.local.yml run --rm api bin/rails db:prepare
```

Confirms the `record_id` uuid migration (§1) applies cleanly to a brand-new database, and seeds
the DB (including a default admin user — see output for credentials, or `db/seeds/admin_user.rb`
for the defaults: username `MPRT/DOF-001`, password `ChangeMe123!` unless overridden by
`ADMIN_DEFAULT_USERNAME`/`ADMIN_DEFAULT_PASSWORD`).

### 3.5 Bring up the app, exercise both flows over real HTTP

```bash
docker compose --env-file .env.docker-test -f docker-compose.production.local.yml up -d --build api jobs
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:3000/up   # expect 200
```

**Public bucket flow** — log in, create a `Dictionary` with an image, confirm the response's
`image_url` is a direct (unsigned) URL and that the bytes are actually fetchable anonymously:

```bash
TOKEN=$(curl -s -i -X POST http://localhost:3000/api/v1/auth/sign_in \
  -H "Content-Type: application/json" \
  -d '{"user":{"username":"MPRT/DOF-001","password":"ChangeMe123!"}}' \
  | grep -i "^authorization:" | sed 's/authorization: //I' | tr -d '\r')

curl -s -X POST http://localhost:3000/api/v1/dictionaries \
  -H "Authorization: Bearer ${TOKEN}" \
  -F "dictionary[local_name]=Test Fish" \
  -F "dictionary[image]=@/path/to/any.png;type=image/png"
# -> image_url should look like http://minio:9000/dofi-docker-test-public/<key>
#    (or the real public endpoint, if MINIO_PUBLIC_ENDPOINT is set)

# fetch it anonymously, from inside the docker network:
docker compose -f docker-compose.production.local.yml exec -T api \
  curl -s -o /dev/null -w "HTTP %{http_code}\n" "<the image_url from above>"
# -> HTTP 200
```

**Private bucket / redirect flow** — `CompaniesDocument` (company registration/licence PDFs) is the
real private-tier model today; prefer exercising the actual endpoints (`POST
/api/v1/company_profiles/:id/documents`, then `GET /api/v1/attachments/:signed_id`) over the
synthetic recipe below. The manual `bin/rails runner` version is still useful for a from-scratch
bucket/policy smoke test that doesn't depend on any app-level model or fixture data:

```bash
docker compose -f docker-compose.production.local.yml exec -T api bin/rails runner '
  ActiveStorage::Current.url_options = { host: "localhost", port: 3000 }
  d = Dictionary.create!(local_name: "Private Path Smoke Test")
  blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("private bytes"), filename: "secret.pdf",
                                                 content_type: "application/pdf", service_name: :minio)
  ActiveStorage::Attachment.create!(name: "private_test", record: d, blob: blob)
  puts blob.signed_id
'
```

```bash
SIGNED_ID="<paste the printed signed_id>"
curl -s -o /dev/null -w "HTTP %{http_code}\n" "http://localhost:3000/api/v1/attachments/${SIGNED_ID}"
# -> 401 (no auth header)

curl -si "http://localhost:3000/api/v1/attachments/${SIGNED_ID}" -H "Authorization: Bearer ${TOKEN}"
# -> 302, Location: a presigned MinIO URL. Follow it (from inside the docker network, since it
#    points at minio:9000) to confirm it actually resolves to 200 with the right bytes.
```

### 3.5.1 Test an actual purge/delete, not just create+read

> ⚠️ **Don't skip this.** A real bug (found 2026-07-28, testing against staging — see
> `docs/incidents/MINIO-STAGING-TEST-REPORT-2026-07-28.md`) only shows up on delete: the scoped IAM policies
> initially had `s3:GetObject`/`PutObject`/`DeleteObject` but not `s3:ListBucket`. Active Storage's
> `Blob#delete` calls `service.delete_prefixed("variants/#{key}/")` for any **image** blob to clean
> up variants — that needs `s3:ListBucket` on the bucket itself, not just object-level actions.
> Without it, purging an image blob deletes the original object, then raises
> `Aws::S3::Errors::AccessDenied` partway through, leaving a dangling DB row. This is invisible to
> both the Minitest suite (only ever runs against Disk, which has no S3-style permissions) and a
> create+read-only manual test — it only shows up when something is actually deleted:

```bash
# Destroy the Dictionary created in §3.5's public-bucket test — this triggers the default
# `dependent: :purge_later`, exercising the real, normal deletion path (not a direct .purge call).
docker compose -f docker-compose.production.local.yml exec -T api bin/rails runner '
  d = Dictionary.find_by(local_name: "Test Fish")
  d&.destroy
'
# Watch the jobs container process ActiveStorage::PurgeJob — must show BOTH
# "Deleted file from key" AND "Deleted files by key prefix", no AccessDenied:
docker compose -f docker-compose.production.local.yml logs jobs --tail=20 | grep -i "purge\|deleted\|error"
```

### 3.6 Tear down

```bash
docker compose --env-file .env.docker-test -f docker-compose.production.local.yml down   # no -v: keeps the data volume
rm -f .env.docker-test .env.production
```

Revert the port-mapping edit in `docker-compose.production.local.yml` if you made one (§3.1).

---

## 4. Staging setup

1. **Rename the existing bucket for symmetry, and add the new credential pair** (§2) to the
   staging server's `.env`. If `MINIO_BUCKET` is currently a bare name like `dofi-staging` (i.e.
   from before this split existed, when there was only one bucket), rename its *value* to
   `dofi-staging-private` — safe to do now specifically because staging hasn't been deployed with
   the two-bucket `mc-init` yet, and the old bucket's only contents are the same test uploads step
   2 below is about to purge anyway. `mc-init` will simply create a new, empty
   `dofi-staging-private` bucket; the old `dofi-staging` bucket is left orphaned on the real MinIO
   server (harmless — delete it later with `mc rb --force local/dofi-staging` once the new setup
   is confirmed working). Don't touch `MINIO_ROOT_USER`/`PASSWORD`/`ENDPOINT`/`ACCESS_KEY_ID`/
   `SECRET_ACCESS_KEY`/`REGION` — only the `MINIO_BUCKET` value changes, plus these three new lines:
   ```
   MINIO_BUCKET=dofi-staging-private
   MINIO_ASSETS_BUCKET=dofi-staging-public
   MINIO_ASSETS_ACCESS_KEY_ID=<generated>
   MINIO_ASSETS_SECRET_ACCESS_KEY=<generated>
   ```
2. **Run the pending `record_id` migration first, deliberately.** Per §1, this purges any existing
   test attachments on staging (their true owning record was unrecoverably lost — see the
   migration's comment). Confirm with whoever's been testing uploads on staging that this is fine
   before deploying, then let the normal `develop` → CD pipeline run `db:prepare` as it always does
   (no separate manual step needed — it's a normal migration).
3. **Push to `develop`** (or merge this branch into it). The existing CD workflow
   (`.github/workflows/cd-staging.yml`) handles the rest: pulls the new image, runs `mc-init`
   (now provisions both buckets + both scoped credentials + the anonymous policy — idempotent, see
   §1), runs `db:prepare`, brings the stack up.
4. **Verify** (SSH to the staging server):
   ```bash
   cd /home/stadmin/st_dofi_backend_staging
   docker compose logs mc-init --tail=50           # confirm both buckets/policies provisioned
   docker compose run --rm mc-init                  # re-run — must still exit 0 (idempotency)
   ```
   Then exercise the public flow the same way as §3.5 (log in, create a `Dictionary` with an
   image, confirm `image_url`, confirm it's fetchable) against the real staging URL.
5. **`MINIO_PUBLIC_ENDPOINT`** (already configured for the private bucket per
   `docs/minio/MINIO-PUBLIC-PROXY-SETUP.md`) now also fronts the public bucket — same proxy, no new
   config needed there. If `image_url` in a real API response still shows `http://minio:9000/...`
   instead of the public endpoint, see that doc's troubleshooting table.

## 5. Production setup

Same steps as staging (§4), with production's existing differences in mind:

- Production's `.env` lives on the dedicated backend server (`docs/ci-cd/CI-CD-SETUP.md`) — same two
  new keys (`MINIO_ASSETS_BUCKET`, `MINIO_ASSETS_ACCESS_KEY_ID`, `MINIO_ASSETS_SECRET_ACCESS_KEY`).
- The `record_id` migration should be run/verified on production **after** staging has proven
  clean, not in parallel — production's deploy is gated behind a required-reviewer GitHub
  Environment approval regardless (`main` → `cd-production.yml`), so there's a natural checkpoint.
- If production doesn't yet have `MINIO_PUBLIC_ENDPOINT` configured at all (per the postmortem's
  action item #2 — still open as of this writing), that's a prerequisite for the public bucket's
  URLs to be browser-reachable too, not just the private bucket's. Follow
  `docs/minio/MINIO-PUBLIC-PROXY-SETUP.md` for that server before or alongside this change.
- Verification: same `mc-init` re-run + real API exercise as staging §4, against the production
  backend server.

---

## 6. Verification checklist (any environment)

- [ ] `mc-init` exits 0 on a **second** run, not just the first.
- [ ] Private bucket: `mc anonymous get local/<MINIO_BUCKET>` reports `private`.
- [ ] Public bucket's **anonymous** policy (`mc anonymous get-json`) shows `s3:GetObject` only,
      principal `*`, **no** `s3:ListBucket` action — this is about unauthenticated access, a
      different thing from the next item.
- [ ] Each app credential's **own** scoped policy (`mc admin policy entities local --user
      <access key>`) shows **exactly one** policy, never both credentials sharing a policy, and
      never the builtin `readwrite` canned policy still attached alongside the scoped one (a real
      leftover found on staging 2026-07-28 — the credential pre-dated this two-bucket split, and
      `attach`ing a new policy doesn't remove an old one).
- [ ] A real `Dictionary` create-with-image round trip returns an `image_url` that is a **direct**
      URL (no `/api/v1/attachments/` in it), and that URL is fetchable without any auth header.
- [ ] `bin/rails db:prepare` (or the CD pipeline's equivalent step) completes without error.
- [ ] **Destroy** that same `Dictionary` (not just create+read) and confirm
      `ActiveStorage::PurgeJob` completes without `Aws::S3::Errors::AccessDenied` — see §3.5.1.
      This is the check that actually catches a missing `s3:ListBucket` grant on the app
      credential's own scoped policy.

## 7. Troubleshooting

See `docs/minio/MINIO.md` §9 (extended this session with two-bucket-specific rows: wrong-bucket
uploads from a `service_name:` mismatch, and public URLs 403ing because `mc-init` hasn't run
since the public bucket was created) and `docs/minio/MINIO-PUBLIC-PROXY-SETUP.md`'s pitfall table for
the reverse-proxy side.
