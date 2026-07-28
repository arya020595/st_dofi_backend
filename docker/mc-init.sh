#!/bin/sh
# Idempotent bucket + credential provisioning, run via `docker compose run --rm mc-init` (see
# docs/MINIO.md §2 "Public vs private buckets" and §6). Safe to re-run on every deploy.
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
    }
  ]
}
EOF
}

# --- Private bucket: no public access, app reads it only via presigned URLs. ---
mc mb --ignore-existing "local/$MINIO_BUCKET"
scoped_readwrite_policy "$MINIO_BUCKET"
mc admin policy create local dofi-private-readwrite "$policy_file"
mc admin user add local "$MINIO_ACCESS_KEY_ID" "$MINIO_SECRET_ACCESS_KEY"
# `attach` exits 1 ("policy change is already in effect") once already attached — confirmed,
# unresolved upstream: https://github.com/minio/mc/issues/4863. That's a no-op, not a real
# failure, but under `set -e` it would otherwise kill every deploy after the first.
mc admin policy attach local dofi-private-readwrite --user "$MINIO_ACCESS_KEY_ID" || true

# --- Public assets bucket: same scoped-readwrite shape for the app's own credential, plus an
# anonymous policy granting GetObject only — never ListBucket, so the bucket's contents can't be
# enumerated even though individual objects are world-readable. ---
mc mb --ignore-existing "local/$MINIO_ASSETS_BUCKET"
scoped_readwrite_policy "$MINIO_ASSETS_BUCKET"
mc admin policy create local dofi-assets-readwrite "$policy_file"
mc admin user add local "$MINIO_ASSETS_ACCESS_KEY_ID" "$MINIO_ASSETS_SECRET_ACCESS_KEY"
# See the `|| true` comment above — same idempotency caveat applies here.
mc admin policy attach local dofi-assets-readwrite --user "$MINIO_ASSETS_ACCESS_KEY_ID" || true

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
