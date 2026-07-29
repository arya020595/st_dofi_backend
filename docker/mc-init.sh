#!/bin/sh
# Idempotent bucket + credential provisioning, run via `docker compose run --rm mc-init` (see
# docs/minio/MINIO.md §2 "Public vs private buckets" and §6). Safe to re-run on every deploy.
#
# Two buckets, two scoped app credentials, two custom (not canned) policies — deliberately not
# MinIO's builtin `readwrite` canned policy, which defaults to every bucket in the deployment
# (arn:aws:s3:::*), not just the one this script just created. A credential leak on one tier must
# not reach the other, so each app user's policy is scoped to that one bucket's ARN only.
set -eu

mc alias set local "http://minio:9000" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"

policy_file=$(mktemp)
trap 'rm -f "$policy_file"' EXIT

scoped_readwrite_policy() {
  bucket="$1"
  cat > "$policy_file" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:AbortMultipartUpload",
        "s3:ListMultipartUploadParts"
      ],
      "Resource": ["arn:aws:s3:::${bucket}/*"]
    },
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": ["arn:aws:s3:::${bucket}"]
    }
  ]
}
EOF
}
# ^ s3:ListBucket (on the bucket ARN itself, not .../* ) is required for
# ActiveStorage::Blob#delete's variant cleanup (service.delete_prefixed("variants/#{key}/"),
# called whenever a purged blob is an image) — it lists keys under that prefix before deleting
# them. Without it, purging an image blob deletes the original object fine, then raises
# Aws::S3::Errors::AccessDenied partway through, leaving the DB row/purge job in a broken state.
# Found by purging a real image blob against real MinIO on staging — the Minitest suite can't
# catch this (it only ever runs against the Disk service, which has no S3-style permissions), and
# local real-MinIO testing (docs/minio/MINIO-TWO-BUCKET-SETUP.md) hadn't exercised an actual purge.

# --- Private bucket: no public access, app reads it only via presigned URLs. ---
mc mb --ignore-existing "local/$MINIO_BUCKET"
scoped_readwrite_policy "$MINIO_BUCKET"
mc admin policy create local dofi-private-readwrite "$policy_file"
mc admin user add local "$MINIO_ACCESS_KEY_ID" "$MINIO_SECRET_ACCESS_KEY"
# `attach` exits 1 ("policy change is already in effect") once already attached — confirmed,
# unresolved upstream: https://github.com/minio/mc/issues/4863. That's a no-op, not a real
# failure, but under `set -e` it would otherwise kill every deploy after the first.
mc admin policy attach local dofi-private-readwrite --user "$MINIO_ACCESS_KEY_ID" || true
# This user may already exist from before this two-bucket split, when it was provisioned with
# MinIO's builtin `readwrite` canned policy (arn:aws:s3:::* — every bucket, not just this one).
# `attach` above only adds the new scoped policy; it doesn't remove that old one, so a credential
# created before this script existed would otherwise still carry full access to every bucket in
# the deployment, silently defeating the point of the split. Detach errors if it was never
# attached (fresh installs, or already cleaned up), which is a no-op, not a real failure.
mc admin policy detach local readwrite --user "$MINIO_ACCESS_KEY_ID" || true

# --- Public assets bucket: same scoped-readwrite shape for the app's own credential, plus an
# anonymous policy granting GetObject only — never ListBucket, so the bucket's contents can't be
# enumerated even though individual objects are world-readable. ---
mc mb --ignore-existing "local/$MINIO_ASSETS_BUCKET"
scoped_readwrite_policy "$MINIO_ASSETS_BUCKET"
mc admin policy create local dofi-assets-readwrite "$policy_file"
mc admin user add local "$MINIO_ASSETS_ACCESS_KEY_ID" "$MINIO_ASSETS_SECRET_ACCESS_KEY"
# See the `|| true` comments above — same idempotency caveats apply here. This is a brand-new
# credential in every environment so far (never existed under the old single-bucket scheme), but
# the detach is harmless and future-proofs against ever reusing an old key for this role.
mc admin policy attach local dofi-assets-readwrite --user "$MINIO_ASSETS_ACCESS_KEY_ID" || true
mc admin policy detach local readwrite --user "$MINIO_ASSETS_ACCESS_KEY_ID" || true

cat > "$policy_file" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"AWS": ["*"]},
      "Action": ["s3:GetObject"],
      "Resource": ["arn:aws:s3:::${MINIO_ASSETS_BUCKET}/*"]
    }
  ]
}
EOF
mc anonymous set-json "$policy_file" "local/$MINIO_ASSETS_BUCKET"
