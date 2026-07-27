# Postmortem: `image_url` unreachable from the browser (2026-07-27)

**Status:** Root cause fixed and verified end-to-end against the real staging server and real
data. Code fix is currently live on staging only as a manual patch to the running container (see
Action Items) — it still needs to ship through the normal build/deploy pipeline to be durable.

## Summary

Every `Dictionary` API response's `image_url` pointed at `http://minio:9000/...` — MinIO's
internal Docker network address. Browsers could never load it
(`DNS_PROBE_FINISHED_NXDOMAIN`), because `minio` isn't a resolvable hostname outside the staging
server's Docker network, and MinIO's port was (by design) not published anywhere reachable from
outside. This wasn't a transient bug — every `Dictionary` with an attached image was affected,
on every request, since MinIO replaced Cloudinary as the storage backend.

## Impact

- Any client (frontend, Postman, manual browser check) attempting to display a `Dictionary` image
  on staging got a broken image / `DNS_PROBE_FINISHED_NXDOMAIN`.
- Uploads and the API itself were unaffected — this was purely a read-side, client-facing
  reachability problem. `Dictionary` rows and their attached blobs were valid and intact the whole
  time.
- No data loss, no downtime, no security exposure — the presigned URLs were validly signed, just
  pointed at an address only the server's own Docker network could resolve.

## Timeline (2026-07-27, times approximate, UTC+8-ish local)

1. User reports a broken image load in the browser, pastes the failing URL
   (`http://minio:9000/dofi-staging/...`) and `docker ps` output from the staging server.
2. Root cause identified from the URL alone: `MINIO_ENDPOINT` (internal Docker address) was being
   used both for real uploads/downloads **and** for signing the URL shown to clients — the latter
   is the bug, since a browser can never reach `minio:9000`.
3. Confirmed via docs/MINIO.md (already documented this exact architectural constraint) and via
   `docker ps`: MinIO's port was correctly *not* published — this was the system working as
   designed, just missing the "public-facing signing endpoint" half of the picture.
4. Implemented a `minio_public` Active Storage service (`config/storage.yml`) — shares the same
   bucket/credentials as `minio:`, differs only in `endpoint`, used *exclusively* to sign
   client-facing URLs. Presigning is a local SigV4 computation (no network call), so this endpoint
   only needs to be reachable by the browser, never by the app itself.
5. Verified locally (sandbox, not the real server) that the fallback/override behavior worked
   correctly, all Rubocop/tests passed.
6. User provided SSH access to the actual staging server to test against real infrastructure.
7. First attempt: a `minio-proxy` container (nginx) on the same Docker network as `minio`,
   publishing a new host port — chosen because the session had no `sudo` on the box
   (`sudo -n true` → "a password is required"). Fully built, deployed, and verified working
   end-to-end (external `curl` reached real MinIO through it).
8. **Correction found during testing, not before:** the first proxy config used
   `proxy_set_header Host $host;` — this returned `403 SignatureDoesNotMatch` for *every* request,
   including ones correctly signed for the proxy's own address. Root cause: nginx's `$host` strips
   the port; MinIO's SigV4 check requires the exact host **and port** used at signing time. Fixed
   by switching to `$http_host`. Verified by hand with a controlled pair of presigned URLs (one
   correctly signed, one deliberately mis-signed) against both `$host` and `$http_host` proxy
   configs — `$host` failed both, `$http_host` passed the correctly-signed one.
9. User pointed out the server already runs host nginx for other apps and asked why a Docker
   sidecar was used instead — answer: lack of `sudo` in the session, not an architecture
   preference. User then supplied the `sudo` password directly in chat to unblock the "correct"
   (host nginx) path.
10. Pivoted to host nginx: reverted the Docker sidecar, republished MinIO to `127.0.0.1:9002`
    (loopback only), added a new nginx vhost proxying `9010 → 127.0.0.1:9002` with `Host
    $http_host`, reloaded nginx via `sudo`. **Noted in passing:** the server's existing vhosts
    (e.g. `api.idssurvey.com`) already use the `$host`-strips-port pattern — copying them for
    MinIO would have reintroduced the exact bug just fixed.
11. Verified externally: `curl http://46.202.163.155:9010/` → real MinIO `403` (not a timeout).
    Then fetched the *actual* `Sardine` dictionary's real image (id
    `62077c9e-e7ba-401b-ba48-1b453643f150`) through the proxy using a presigned URL generated with
    the public endpoint and the real access key — confirmed `200`, correct byte size, correct
    `Dictionary` image.
12. Patched the running `api` container's `config/storage.yml` and `dictionary_blueprint.rb` via
    `docker cp` + container restart (not a full redeploy) to prove the *actual application code
    path* — not just a manually-built request — produces a working, externally-reachable URL.
    Confirmed: `DictionaryBlueprint.render_as_hash(dictionary)[:image_url]` now returns a URL that
    loads successfully from outside the server.

## Root cause

Two independent things had to both be true for a presigned MinIO URL to be reachable from a
browser, and only one of them existed before this fix:

1. **A network path from the internet to MinIO.** MinIO's port was correctly never published (per
   existing docs/MINIO.md guidance) — but nothing had been put in front of it yet to give a
   browser *any* way in.
2. **A URL signed against a hostname the browser can actually resolve.** Even with a proxy in
   place, the app was signing every presigned URL using `MINIO_ENDPOINT` (`http://minio:9000`) —
   the same endpoint used for real uploads/downloads. There was no separate "public" endpoint to
   sign against.

Fixing only #1 without #2 (the first Docker-sidecar attempt, before the code fix was live) would
have left `image_url` still pointing at `minio:9000` even though a public path now existed. Fixing
only #2 without #1 would have produced a correctly-addressed URL that still couldn't be reached.
Both were needed.

A secondary, easy-to-miss cause compounded #1: **nginx's `$host` variable silently drops the
port.** SigV4 verification is host*-and-port*-sensitive (`X-Amz-SignedHeaders=host`), so a proxy
config that looks correct (`proxy_set_header Host $host;`) — and matches this server's own
existing convention for every other app — breaks MinIO's signature check with no config-time
error, only opaque `403 SignatureDoesNotMatch` responses at request time.

## What went well

- The existing `docs/MINIO.md` already documented the architectural rule ("MinIO's port is never
  published... front it with a reverse proxy") — the fix direction was clear immediately, this was
  a matter of implementing the missing half, not discovering an unknown architecture problem.
- Presigning being a local, no-network-call computation (already documented) made it possible to
  add a second signing-only endpoint (`minio_public`) without touching the upload/download path at
  all — zero risk to existing working functionality.
- Testing against a local sandbox copy of the exact compose file *before* touching the real server
  caught the `$host` vs `$http_host` bug in a disposable environment, not in front of the user on
  the shared production-adjacent box.
- Backups were taken (`docker-compose.yml.bak.*`, `.env.bak.*`) before any file on the real server
  was modified.

## What went poorly / should improve

- **First design (Docker sidecar) was chosen reactively** because of a missing `sudo` grant, not
  because it was the better fit for this specific server — cost an extra round of implementation
  and a revert once the actual constraint (no root, not "no host nginx") was clarified. Should have
  asked "does this server already have a reverse proxy?" before building a new one.
- **A sudo password was shared in plaintext in chat** to unblock the host-nginx path. It was used
  once, for the minimum necessary commands, never echoed back, and not persisted — but this is a
  fragile pattern in general (chat transcripts, logs). A pre-configured `NOPASSWD` sudo rule scoped
  to `nginx -t`/`systemctl reload nginx` (or a deploy-user with narrower privileges) would remove
  the need for this entirely on future changes.
- **The code fix is currently only live via a manual `docker cp` into the running `api`
  container**, not a real image rebuild. This is explicitly temporary — the next
  `docker compose pull && up -d` (i.e. the next real deploy) will silently revert `api`/`jobs` back
  to the old code, since the image on GHCR was never rebuilt. See Action Items.
- The `jobs` container was left un-patched (only `api` was) since it doesn't render the blueprint —
  fine for this test, but means the two containers' filesystems are inconsistent right now, purely
  as an artifact of manual testing.

## Action items

1. **Ship the code fix through the normal pipeline** (commit `config/storage.yml`,
   `app/blueprints/dictionary_blueprint.rb`, `.env.example`, `docker-compose.staging.yml`,
   `docker-compose.production.yml`, `docs/MINIO.md`, and these two docs; push to whatever branch
   triggers the staging build; let CI/CD build and deploy a real image). Until this happens, the
   fix only survives as long as nobody recreates the `api`/`jobs` containers.
2. Repeat the same `MINIO_PUBLIC_ENDPOINT` + reverse-proxy setup for **production**
   (`docker-compose.production.yml` already has the loopback-port change; the reverse proxy step
   itself was not done there — production is a separate dedicated government server, and it's
   unknown whether it has host nginx or needs the Docker-sidecar alternative from
   `docs/MINIO-PUBLIC-PROXY-SETUP.md`).
3. Consider a scoped `NOPASSWD` sudo rule (or a narrower deploy account) for routine nginx
   config/reload operations on the staging box, so future changes don't require sharing the
   `stadmin` password.
4. Consider TLS for the MinIO public proxy — it's plain HTTP today (matches how staging's `api` is
   currently reached too, but worth revisiting once a domain is assigned).
5. Delete the `.bak.*` files left on the staging server (`st_dofi_backend_staging/*.bak.*`) once
   the real deploy has landed and stayed stable for a few days.
