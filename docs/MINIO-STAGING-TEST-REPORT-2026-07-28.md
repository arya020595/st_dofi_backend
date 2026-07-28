# Staging Test Report: Two-Bucket MinIO Split (2026-07-28)

**Status:** Both buckets (private and public) verified working end-to-end against the real
staging server. Two real bugs were found and fixed — one in live MinIO state directly, one also
fixed in code (`docker/mc-init.sh`). **Read "What still needs to happen" before doing anything
else on staging or production — the code fix has not been deployed yet.**

Server tested: `stadmin@46.202.163.155`, `/home/stadmin/st_dofi_backend_staging`.

---

## 1. Summary

| Check | Result |
|---|---|
| Two-bucket code actually deployed to staging | ✅ Yes — already live before this test started |
| `mc-init` provisions both buckets, idempotent re-run | ✅ Yes (exit 0 both times) |
| Private bucket: zero anonymous access | ✅ Confirmed (`private`) |
| Public bucket: anonymous `GetObject` only, no `ListBucket` | ✅ Confirmed |
| Public bucket upload → `image_url` → anonymous fetch, real HTTP, real bytes | ✅ Confirmed, after fixing a stale-container-env issue (§2.1) |
| Private bucket → `302` redirect → presigned URL → real HTTP fetch | ✅ Confirmed |
| Tampered/missing signature on the private bucket rejected | ✅ Confirmed (`403`) |
| `record_id` UUID migration applied, old attachments purged | ✅ Confirmed (0 leftover attachments) |
| App credentials scoped to exactly one bucket each | ❌ → ✅ Fixed live (§2.2) — was leaking full cross-bucket access |
| Deleting an image attachment (not just create+read) | ❌ → ✅ Fixed live + in code (§2.3) — was raising `AccessDenied` |

---

## 2. Issues found and fixed

### 2.1 Stale container env (operational, not a code bug)

**Symptom:** First upload attempt failed with `"Image could not be uploaded: Access Denied."`

**Cause:** The `api`/`jobs` containers had been created *before* `.env` was updated with the final
bucket names/credentials. `env_file:` values are read once at container creation — `docker compose
up -d` alone doesn't necessarily recreate a container just because `.env` changed underneath it.
The running app was still using `MINIO_BUCKET=dofi-staging` / `MINIO_ASSETS_BUCKET=dofi-staging-assets`
(the old names), while `mc-init` had just provisioned buckets/policies for the new names
(`dofi-staging-private` / `dofi-staging-public`) — a real mismatch, not a permissions problem.

**Fix:** `docker compose up -d --force-recreate api jobs`. Confirmed via `docker compose exec api
env | grep MINIO_` that the values now match `.env`.

### 2.2 Old broad `readwrite` policy still attached (security issue, fixed live + in code)

**Symptom:** `mc admin policy entities local --user <MINIO_ACCESS_KEY_ID>` showed **two** policies:
`dofi-private-readwrite, readwrite`.

**Cause:** This app credential existed *before* the two-bucket split, provisioned back then with
MinIO's builtin `readwrite` canned policy (`arn:aws:s3:::*` — every bucket in the deployment, not
just its own). `mc-init`'s `attach` only *adds* the new scoped policy; it never removed the old
one. Net effect: this credential still had full read/write on **every** bucket, including the
public one — silently defeating the entire point of splitting credentials by tier.

**Fixed live:** `mc admin policy detach local readwrite --user <MINIO_ACCESS_KEY_ID>`. Re-verified
read access still worked afterward (only the scoped policy is needed).

**Fixed in code:** `docker/mc-init.sh` now runs `mc admin policy detach local readwrite --user ...`
(with `|| true`, since it errors harmlessly if already detached) for **both** app credentials, on
every run — so this can't silently reappear, and any environment with a pre-existing credential
(production almost certainly has the same leftover) gets cleaned up automatically next deploy.

### 2.3 Missing `s3:ListBucket` — deleting an image raised `AccessDenied` (blocking, fixed live + in code)

**Symptom:** Cleaning up test data — `Dictionary#destroy` (image attached) → `AccessDenied`,
stack trace pointing at `ActiveStorage::Service::S3Service#delete_prefixed` → `list_objects_v2`.

**Cause:** The scoped policy for both buckets granted `GetObject`/`PutObject`/`DeleteObject`/
`AbortMultipartUpload`/`ListMultipartUploadParts` on `arn:aws:s3:::<bucket>/*` — object-level
actions only. `ActiveStorage::Blob#delete` calls `service.delete_prefixed("variants/#{key}/")` for
any **image** blob (to clean up variants), which requires `s3:ListBucket` on the bucket ARN itself
(not `.../*`). Without it: the main object deletes fine, then the variant-cleanup step throws,
leaving the operation half-done. Confirmed directly — `mc ls` as either app credential failed with
`Access Denied` before the fix, succeeded after.

**Why this went undetected until now:** the Minitest suite only ever runs against the Disk
service (no S3-style IAM at all), and this session's earlier local Docker/real-MinIO testing
(`docs/MINIO-TWO-BUCKET-SETUP.md` §3) exercised create+read but never an actual delete. This is
now closed — see §3.5.1 in that doc, added as a direct result of this finding.

**Fixed live:** re-issued both scoped policies (`mc admin policy create`, which updates in place)
with an added statement: `{"Effect":"Allow","Action":["s3:ListBucket"],"Resource":["arn:aws:s3:::<bucket>"]}`.
Verified: `mc ls` now succeeds for both credentials, and a full `Dictionary` create → destroy →
`ActiveStorage::PurgeJob` cycle completes cleanly (both `Deleted file from key` and `Deleted files
by key prefix`, no error).

**Fixed in code:** `docker/mc-init.sh`'s `scoped_readwrite_policy()` now includes this statement
for both buckets.

---

## 3. What still needs to happen

**The code fix (§2.2, §2.3) has not been deployed.** Both fixes were applied directly to the live
MinIO state (via `mc admin policy create`/`detach`), which is correct and necessary for testing —
but the `docker/mc-init.sh` file sitting on the staging server right now is still the *old* version
without these two fixes. If `mc-init` runs again before this code ships — which it will, on the
very next normal deploy — it will **silently overwrite the live policy back to the broken version**
(`mc admin policy create` replaces the whole policy document; the old script doesn't know about
the `ListBucket` statement or the `readwrite` detach).

**Action needed:** get this branch's `docker/mc-init.sh` change merged and deployed through the
normal `develop` → `cd-staging.yml` pipeline as soon as reasonably possible, so the file on the
server matches what's actually been verified. Until then, avoid manually re-running `mc-init` on
staging outside of a real deploy.

Test data created during this session (three `Dictionary` rows named `*TEST - DELETE ME` and their
attachments/blobs) was fully cleaned up — final state confirmed: 101 dictionaries (original count),
0 attachments, 0 blobs.

---

## 4. How to test this yourself

### 4.1 Quick health check (read-only, safe to run anytime)

```bash
ssh stadmin@<server-ip>
cd /home/stadmin/st_dofi_backend_staging   # or _production

docker compose ps                                    # api/jobs/db/minio all healthy?
docker compose exec api env | grep MINIO_             # matches current .env? (see §2.1 if not)
docker compose run --rm mc-init                       # must exit 0 — idempotency check
```

### 4.2 Verify bucket policies and credential scoping

```bash
docker compose run --rm --entrypoint sh mc-init -c '
  mc alias set local http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null
  echo "--- private bucket (expect: private) ---"
  mc anonymous get "local/$MINIO_BUCKET"
  echo "--- public bucket anonymous policy (expect: GetObject only, no ListBucket) ---"
  mc anonymous get-json "local/$MINIO_ASSETS_BUCKET"
  echo "--- each credential should show exactly ONE policy, never readwrite ---"
  mc admin policy entities local --user "$MINIO_ACCESS_KEY_ID"
  mc admin policy entities local --user "$MINIO_ASSETS_ACCESS_KEY_ID"
'
```

### 4.3 Full round trip: public bucket (upload → fetch)

Get a real JWT first (`POST /api/v1/auth/sign_in` with valid credentials — ask whoever manages
staging accounts, or use your own), then:

```bash
TOKEN="<your bearer token>"
SERVER="http://<server-ip>:3012"   # 3012 is staging's published api port

curl -s -X POST "$SERVER/api/v1/dictionaries" \
  -H "Authorization: Bearer ${TOKEN}" \
  -F "dictionary[local_name]=SELF TEST - DELETE ME" \
  -F "dictionary[image]=@/path/to/any.png;type=image/png"
# -> note the "id" and "image_url" in the response

curl -s -o /dev/null -w "HTTP %{http_code}\n" "<image_url from above>"
# -> 200, and no Authorization header was sent — it's a public bucket, this is the whole point
```

### 4.4 Full round trip: private bucket (redirect flow)

Nothing in the app uses the private bucket yet, so this has to be exercised manually — same
approach as local testing (`docs/MINIO-TWO-BUCKET-SETUP.md` §3.5), just point at the real server:

```bash
docker compose exec -T api bin/rails runner '
  ActiveStorage::Current.url_options = { host: "<server-ip>", port: 3012 }
  d = Dictionary.create!(local_name: "SELF TEST PRIVATE - DELETE ME")
  blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("test bytes"), filename: "test.pdf",
                                                 content_type: "application/pdf", service_name: :minio)
  ActiveStorage::Attachment.create!(name: "self_test", record: d, blob: blob)
  puts blob.signed_id
'
```

```bash
SIGNED_ID="<paste from above>"
curl -s -o /dev/null -w "HTTP %{http_code}\n" "$SERVER/api/v1/attachments/${SIGNED_ID}"          # 401, no token
curl -si "$SERVER/api/v1/attachments/${SIGNED_ID}" -H "Authorization: Bearer ${TOKEN}"            # 302 + Location
# follow the Location header — 200, correct bytes
```

### 4.5 The check that actually matters: delete, not just create+read

This is the step that would have caught §2.3 immediately — **always include it**:

```bash
docker compose exec -T api bin/rails runner '
  d = Dictionary.find_by(local_name: "SELF TEST - DELETE ME")
  d&.destroy   # triggers dependent: :purge_later — the real, normal deletion path
'
sleep 3
docker compose logs jobs --tail=15 | grep -i "purge\|deleted\|error"
# must show "Deleted file from key" AND "Deleted files by key prefix", never AccessDenied
```

### 4.6 Clean up

```bash
docker compose exec -T api bin/rails runner '
  Dictionary.where("local_name LIKE ?", "%SELF TEST%").find_each do |d|
    ActiveStorage::Attachment.where(record: d).each { |a| a.purge }  # .purge on the ATTACHMENT,
    d.destroy                                                        # not just the blob — purges
  end                                                                 # blob + destroys the row
'
```

Use `a.purge` (on the `ActiveStorage::Attachment`), not `a.blob.purge` directly — the latter
deletes the blob but leaves the attachment row dangling (found and fixed during this session's
cleanup — see the git history around this doc if the difference ever needs re-deriving).
