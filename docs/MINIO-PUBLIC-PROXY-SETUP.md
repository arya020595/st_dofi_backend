# Tutorial: Setting Up MinIO's Public-Facing Proxy (Correctly)

Step-by-step, verified-by-hand setup for making MinIO URLs reachable from a browser, without ever
exposing MinIO's own port to the internet. This one proxy serves **both** buckets described in
`docs/MINIO.md` §2 — the private bucket's *presigned* URLs and the public assets bucket's plain
*unsigned* URLs both resolve through the same `MINIO_PUBLIC_ENDPOINT`, since the reverse proxy
just forwards to `minio:9000` regardless of which bucket/key is being requested. Read
`docs/MINIO.md` §2 first for the *why*; this doc is only the *how*. See
`docs/POSTMORTEM-2026-07-27-minio-presigned-url.md` for the incident that made this necessary and
the mistakes made (and fixed) while building it — that incident predates the public/private bucket
split, so its worked example (`Dictionary`, presigned) is now out of date; see the note below.

## What you're building

```
Browser ──HTTP(S)──▶ Reverse proxy ──HTTP──▶ 127.0.0.1:9002 ──▶ minio container:9000
                      (public port)          (loopback only)     (never published)
```

MinIO's container port is never published beyond `127.0.0.1` — the reverse proxy is the *only*
thing standing between it and the internet. `api`/`jobs` keep talking to `minio:9000` directly
over the internal Docker network, unaffected by any of this.

## Prerequisites

- `docker-compose.staging.yml` / `docker-compose.production.yml` already publish MinIO as
  `127.0.0.1:9002:9000` (not `0.0.0.0`) — confirm with `docker compose ps`, the `PORTS` column
  should read `127.0.0.1:9002->9000/tcp`.
- Root/sudo access on the server, **if** you're using Option A (host nginx). Option B needs no
  root at all.
- Know the server's public IP or domain, and one free port for the proxy to listen on (`9010` is
  used as the example throughout — pick any free port and open it in your firewall/security group
  if one applies).

## Option A: Host nginx (use this if the server already runs nginx)

This is what staging (`cobtsabah`) uses today — it already runs nginx for other apps
(`accorn.intentharvest.com`, `api.idssurvey.com`, etc.), so this just adds one more vhost.

1. Write the vhost config. **The `Host` header directive is the one line that matters most** —
   see the pitfall below before copying any *other* vhost on this server as a starting point.

   ```nginx
   # /etc/nginx/sites-available/dofi-minio
   server {
       listen 9010;
       server_name _;

       location / {
           proxy_pass http://127.0.0.1:9002;
           proxy_set_header Host $http_host;
       }
   }
   ```

2. Enable it, validate, reload (all need `sudo`):
   ```bash
   sudo cp dofi-minio /etc/nginx/sites-available/dofi-minio
   sudo ln -sf /etc/nginx/sites-available/dofi-minio /etc/nginx/sites-enabled/dofi-minio
   sudo nginx -t                      # must print "syntax is ok" / "test is successful"
   sudo systemctl reload nginx        # zero downtime for other vhosts
   ```

3. Confirm it's reachable (should return MinIO's own `403` — proves the request reached MinIO,
   not "connection refused"/timeout):
   ```bash
   curl -i http://<server-ip>:9010/
   # HTTP/1.1 403 Forbidden  <- correct! means it got to MinIO and MinIO rejected the unsigned request
   ```

### ⚠️ The one mistake that will cost you an hour: `$host` vs `$http_host`

Every other vhost on this server (and most nginx tutorials/examples you'll find) uses:
```nginx
proxy_set_header Host $host;
```
**Do not copy that for MinIO.** nginx's `$host` variable silently **strips the port** from the
Host header. MinIO's SigV4 signature verification checks the incoming request's `Host` header
byte-for-byte (including the port) against what Rails signed the URL with
(`X-Amz-SignedHeaders=host`). If the port is missing, the signature no longer matches — and
**every single request 403s with `SignatureDoesNotMatch`**, including ones signed for the correct
public address. There's no config-time error; it just silently breaks at request time.

Use `$http_host` (the raw, unmodified Host header, port included) instead. This was confirmed by
hand: with `$host`, a URL correctly signed against the public endpoint still 403'd; switching the
one line to `$http_host` fixed it immediately, no other change.

## Option B: Docker-only reverse proxy (no host nginx / no root access)

If the server has no nginx installed and you don't have sudo (e.g. a locked-down dedicated
government box), run the proxy as its own container instead — no root needed, everything lives in
`docker-compose.yml`:

```yaml
  minio-proxy:
    image: nginx:1.27-alpine
    container_name: dofi-backend-<env>-minio-proxy
    restart: unless-stopped
    ports:
      - "9010:80"
    depends_on:
      minio:
        condition: service_healthy
    entrypoint: ["sh", "-c"]
    command:
      - |
        cat > /etc/nginx/conf.d/default.conf <<'EOF'
        server {
            listen 80;
            location / {
                proxy_pass http://minio:9000;
                proxy_set_header Host $$http_host;
            }
        }
        EOF
        exec nginx -g 'daemon off;'
    networks:
      - dofi-backend-<env>-net
```

Notes:
- `$$http_host` (double `$`) — Compose interpolates `$VAR`/`${VAR}` in the source file, so a
  literal `$` in the generated shell script must be escaped as `$$` (same pattern `mc-init` already
  uses elsewhere in these compose files).
- Proxies to `minio:9000` directly over Docker's internal DNS — no loopback-port publish on
  `minio` needed at all in this variant, since both containers share the same Docker network.
- `docker compose up -d` brings it up; `docker compose logs minio-proxy -f` tails it;
  `docker compose up -d --force-recreate minio-proxy` picks up an edited inline config.
- This was tried and fully verified working during the incident this doc follows up on, then
  swapped for Option A once it turned out staging already had host nginx + sudo access available.
  Both are valid; pick based on what the server actually offers.

## Wiring it into the app

1. In that server's `.env`, add (keep the existing `MINIO_ENDPOINT` line untouched):
   ```
   MINIO_PUBLIC_ENDPOINT=http://<server-ip-or-domain>:9010
   ```
2. Restart `api`/`jobs` so they pick up the new `.env` value:
   ```bash
   docker compose restart api jobs
   ```
3. Verify end-to-end against real data. `Dictionary` is on the **public** bucket today, so its
   `image_url` is already a plain, permanent URL through this same proxy — no signature to expire,
   nothing else to configure:
   ```bash
   docker exec <api-container> bin/rails runner '
     d = Dictionary.find("<uuid>")
     puts DictionaryBlueprint.render_as_hash(d)[:image_url]
   '
   ```
   Then `curl` that exact URL from *outside* the server (not from the server itself) and confirm
   `HTTP 200` with the image bytes. To verify the **private** bucket's presigned path specifically
   (relevant once a model actually uses it — see `docs/MINIO.md` §2), hit
   `GET /api/v1/attachments/<signed_id>` instead and confirm the `302 Location` header resolves the
   same way from outside the server.

## Verification checklist

- [ ] `docker compose ps` shows `minio` as `127.0.0.1:9002->9000/tcp` (not `0.0.0.0`, not
      unpublished).
- [ ] `curl http://<server-ip>:<proxy-port>/` from a machine *outside* the server returns MinIO's
      `403` (not a timeout / connection refused / DNS error).
- [ ] `MINIO_PUBLIC_ENDPOINT` is set in that server's `.env` and `api`/`jobs` were restarted after.
- [ ] A real `image_url` from the API, opened in an actual browser (or `curl`'d from off-server),
      returns the image — not `DNS_PROBE_FINISHED_NXDOMAIN`, not a 403.
- [ ] The proxy's `Host` directive is `$http_host`, confirmed by the above actually returning `200`
      rather than `403 SignatureDoesNotMatch`.

## Common pitfalls

| Symptom | Cause |
|---|---|
| Browser gets `DNS_PROBE_FINISHED_NXDOMAIN` | `MINIO_PUBLIC_ENDPOINT` unset, or `api`/`jobs` not restarted after setting it |
| `curl` from outside times out / connection refused | Proxy port not open in the firewall/security group, or MinIO's compose port publish is missing/wrong |
| `403 SignatureDoesNotMatch`, even on a freshly-signed URL | Proxy using `$host` instead of `$http_host` — see the callout above |
| Works when curled from the server itself but not from outside | You tested against `127.0.0.1`/loopback, which bypasses the actual public path — always test from a genuinely external machine |
| Fix "disappears" after a deploy | Code was only `docker cp`'d into a running container for a quick test (not the real fix) — see the postmortem's action items |
