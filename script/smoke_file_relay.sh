#!/usr/bin/env bash
# Smoke test for the file relay (docs/minio/FILE-ACCESS-SEQUENCE.md): upload FE -> BE -> storage, download
# storage -> BE -> FE. Browsers cannot reach the storage server, so every byte must come back through
# GET /api/v1/attachments/:signed_id with a JWT, never as a redirect to a storage URL.
#
#   script/smoke_file_relay.sh BASE_URL FISHERMAN_JWT [OFFICER_JWT]
#
# Point BASE_URL at the address the browser uses, so the Frontend's /api proxy is exercised too, for example
# http://10.246.8.12:4100 (the Frontend's nginx must allow 12 MB bodies; a 413 here is that limit).
# Get a JWT from the login response (`data.access_token`).
#
# What it does, on the fisherman's own company: reads the first vessel, picks one EMPTY image slot (it refuses to
# overwrite an existing picture), uploads a ~3 MB PNG there, fetches it back and compares sha256, then clears the
# slot again. With OFFICER_JWT it also checks the picture shows on the DoFi Officer's Profiling Approval screen.
# The test picture is ~1.9 MB: over nginx's default 1 MB body limit, under the app's 2 MB-per-image limit.
# Run it against staging or a test company; it needs curl, jq, sha256sum and base64.
set -u

BASE="${1:?usage: $0 BASE_URL FISHERMAN_JWT [OFFICER_JWT]}"
FISHERMAN_JWT="${2:?usage: $0 BASE_URL FISHERMAN_JWT [OFFICER_JWT]}"
OFFICER_JWT="${3:-}"
BASE="${BASE%/}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0

pass() { printf '  PASS  %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; failures=$((failures + 1)); }
check() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected $2, got $3)"; fi; }

# http METHOD URL JWT [curl args...] -> prints status code; body in $work/body, headers in $work/headers
http() {
  local method="$1" url="$2" jwt="$3"
  shift 3
  local auth=()
  [ -n "$jwt" ] && auth=(-H "Authorization: Bearer $jwt")
  curl -s -o "$work/body" -D "$work/headers" -w '%{http_code}' -X "$method" "${auth[@]}" -H 'Accept: application/json' \
    "$@" "$BASE$url"
}

echo "Relay smoke test against $BASE"

# A valid 1x1 PNG padded to ~1.9 MB: over nginx's 1 MB default (so a proxy body limit shows up), under the app's
# 2 MB-per-image limit (CompaniesVessel::IMAGE_MAX_SIZE).
png_b64='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='
{ echo "$png_b64" | base64 -d; head -c 1900000 /dev/zero; } > "$work/upload.png"
want_sha="$(sha256sum "$work/upload.png" | cut -d' ' -f1)"
echo "Test image: $(stat -c %s "$work/upload.png") bytes (above nginx's 1 MB default, under the 2 MB app limit)"

echo "1. Find the fisherman's company, vessel and an empty image slot"
status="$(http GET /api/v1/fisherman/company_profiles "$FISHERMAN_JWT")"
check "list own company" 200 "$status"
company_id="$(jq -r '.data[0].id // empty' "$work/body")"
status="$(http GET "/api/v1/fisherman/company_profiles/$company_id/vessels" "$FISHERMAN_JWT")"
check "list vessels" 200 "$status"
vessel_id="$(jq -r '.data[0].id // empty' "$work/body")"
slot="$(jq -r '.data[0].images | to_entries | map(select(.value == null)) | .[0].key // empty' "$work/body")"
if [ -z "$company_id" ] || [ -z "$vessel_id" ] || [ -z "$slot" ]; then
  fail "need a vessel with at least one empty image slot (company='$company_id' vessel='$vessel_id' slot='$slot')"
  exit 1
fi
echo "   company $company_id, vessel $vessel_id, using empty slot '$slot'"
images_path="/api/v1/fisherman/company_profiles/$company_id/vessels/$vessel_id/images"

echo "2. Upload (FE -> BE -> storage)"
status="$(http POST "$images_path" "$FISHERMAN_JWT" -F "images[$slot]=@$work/upload.png;type=image/png")"
check "upload through the proxy (413 = the Frontend nginx body limit)" 200 "$status"
file_path="$(jq -r ".data.images.$slot.url // empty" "$work/body")"
case "$file_path" in
  /api/v1/attachments/*) pass "response carries a relay path, not a storage URL" ;;
  *) fail "response path is '$file_path'"; exit 1 ;;
esac

echo "3. Download (storage -> BE -> FE)"
status="$(http GET "$file_path" "$FISHERMAN_JWT")"
check "fetch with the JWT" 200 "$status"
check "bytes are identical to the upload" "$want_sha" "$(sha256sum "$work/body" | cut -d' ' -f1)"
if grep -qi '^location:' "$work/headers"; then fail "answered with a redirect (Location header)"; else pass "no redirect"; fi
grep -qi '^content-type: image/png' "$work/headers" && pass "content type image/png" || fail "content type"
status="$(http GET "$file_path" "")"
check "without a JWT" 401 "$status"
status="$(http GET /rails/active_storage/blobs/proxy/x/y.png "")"
check "Active Storage's own proxy route is closed" 404 "$status"

if [ -n "$OFFICER_JWT" ]; then
  echo "4. DoFi Officer: Profiling Approval shows the picture"
  status="$(http GET "/api/v1/admin/approvals/vessels/$vessel_id" "$OFFICER_JWT")"
  check "approval detail" 200 "$status"
  approval_path="$(jq -r ".data.images.$slot.url // empty" "$work/body")"
  if [ -n "$approval_path" ]; then
    pass "approval response lists the image"
    status="$(http GET "$approval_path" "$OFFICER_JWT")"
    check "officer fetches it (403 = role lacks company_profiles.view)" 200 "$status"
    check "officer gets the same bytes" "$want_sha" "$(sha256sum "$work/body" | cut -d' ' -f1)"
  else
    fail "approval response has no images.$slot (backend without the approval images fix?)"
  fi
fi

echo "5. Clean up the test picture"
status="$(http DELETE "$images_path/$slot" "$FISHERMAN_JWT")"
check "slot '$slot' cleared again" 200 "$status"

echo
if [ "$failures" -eq 0 ]; then echo "All checks passed."; else echo "$failures check(s) failed."; fi
exit "$failures"
