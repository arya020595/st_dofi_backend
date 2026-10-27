# Runbook: Serving MinIO's Public Endpoint Over HTTPS (Fixing Mixed Content)

How to move `MINIO_PUBLIC_ENDPOINT` from a plain `http://<ip>:9010` address to an
`https://<subdomain>` address, so a browser on an HTTPS frontend can load attachments and images.
This builds on `docs/minio/MINIO-PUBLIC-PROXY-SETUP.md` (the HTTP proxy that already exists) and
`docs/minio/MINIO.md` §2 (why there is a separate public endpoint at all). Read those for the
background; this doc is only the HTTPS step.

> **Status: proposed, not yet applied.** Staging currently uses
> `MINIO_PUBLIC_ENDPOINT=http://46.202.163.155:9010`. Do step 0 first — the fix below assumes the
> failure is mixed content, which was inferred from server-side checks, not yet seen in a browser.

## The problem

`GET /api/v1/attachments/:signed_id` works and answers `302 Found`. The `Location` it returns is built
from `MINIO_PUBLIC_ENDPOINT` (`Attachments::PublicUrl`), so today it points at
`http://46.202.163.155:9010/dofi-staging-private/...`.

The API (`https://api-dofi.datablu.asia`) and the frontend are served over HTTPS. A browser blocks an
HTTPS page from loading an `http://` resource (**mixed content**), so the request dies right after the
302 and the file never shows.

Already checked from outside the server on 2026-10-02, all fine, so they are *not* the cause:

- The nginx proxy on port 9010 reaches MinIO (`/minio/health/live` returns 200).
- `Host $http_host` is already used in `/etc/nginx/sites-available/dofi-minio`.
- CORS: a preflight from `https://dofi.datablu.asia` gets `204` with
  `Access-Control-Allow-Origin: https://dofi.datablu.asia`.

The same applies to public-bucket URLs (e.g. `Dictionary#image_url`): they use the same
`MINIO_PUBLIC_ENDPOINT`, so they have the same mixed-content problem.

## Step 0: Confirm the diagnosis in the browser

Open DevTools on the frontend, trigger an attachment load, and look at the request that follows the
302.

| What you see | Meaning | Go to |
|---|---|---|
| `(blocked:mixed-content)` in Network, or "Mixed Content: ... requested an insecure ..." in Console | Diagnosis confirmed | Step 1 |
| `403` with `SignatureDoesNotMatch` | Proxy `Host` header or wrong endpoint signed | `MINIO-PUBLIC-PROXY-SETUP.md` pitfalls |
| CORS error, no response headers | MinIO CORS origin does not include the frontend's origin | Check the CORS setting on the `minio` service |
| `ERR_CONNECTION_REFUSED` / timeout | Port or firewall | Open the port / check nginx |

## What you're building

```
Browser ──HTTPS :443──▶ host nginx (TLS) ──HTTP──▶ 127.0.0.1:9002 ──▶ minio container:9000
        minio-dofi.datablu.asia                     (loopback only)
```

Same shape as before, but the public side is a real hostname on 443 with a Let's Encrypt certificate.
`api`/`jobs` still talk to `minio:9000` over the internal network and are unaffected.

`minio-dofi.datablu.asia` is used as the example name throughout — pick any subdomain you control.

## Prerequisites

- DNS: an `A` record for the chosen subdomain pointing at the staging server (`46.202.163.155`). It
  must resolve before step 2, or certbot cannot issue the certificate.
- `sudo` on the server (host nginx and certbot both need it). Certbot is already in use here: the
  `api-dofi.datablu.asia` vhost is "managed by Certbot".
- Ports 80 and 443 reachable from the internet (they already are — nginx serves other sites on them).

## Step 1: Add DNS

Create the record at your DNS provider, then confirm from your own machine:

```bash
dig +short minio-dofi.datablu.asia     # must print 46.202.163.155
```

## Step 2: Add the nginx vhost

Start with an HTTP-only vhost; certbot rewrites it to add TLS.

```nginx
# /etc/nginx/sites-available/dofi-minio-https
server {
    listen 80;
    server_name minio-dofi.datablu.asia;

    # Presigned uploads/downloads can be large; nginx's 1m default would reject bigger bodies.
    client_max_body_size 100m;

    location / {
        proxy_pass http://127.0.0.1:9002;
        proxy_set_header Host $http_host;   # NOT $host — see the callout in MINIO-PUBLIC-PROXY-SETUP.md
        proxy_buffering off;                # stream large files instead of spooling them to disk
    }
}
```

Enable it, validate, reload, then issue the certificate:

```bash
sudo cp dofi-minio-https /etc/nginx/sites-available/dofi-minio-https
sudo ln -sf /etc/nginx/sites-available/dofi-minio-https /etc/nginx/sites-enabled/dofi-minio-https
sudo nginx -t
sudo systemctl reload nginx

sudo certbot --nginx -d minio-dofi.datablu.asia
```

Certbot adds the `listen 443 ssl` block and the HTTP→HTTPS redirect. After it finishes, re-open the
file and confirm the `proxy_set_header Host $http_host;` line is still there — certbot should not touch
it, but this is the one line whose loss breaks every signature.

Leave the existing `dofi-minio` vhost on port 9010 in place for now; it is the rollback path.

## Step 3: Verify the proxy before touching the app

From a machine **outside** the server:

```bash
curl -i https://minio-dofi.datablu.asia/
# HTTP/2 403   <- correct: the request reached MinIO and it rejected the unsigned request

curl -i -X OPTIONS https://minio-dofi.datablu.asia/dofi-staging-private/x \
  -H "Origin: https://dofi.datablu.asia" -H "Access-Control-Request-Method: GET"
# 204 with Access-Control-Allow-Origin: https://dofi.datablu.asia
```

A TLS error here means certbot did not finish; a timeout means DNS or the firewall.

## Step 4: Point the app at it

On the staging server, in `~/st_dofi_backend_staging/.env`, change only this line (leave
`MINIO_ENDPOINT=http://minio:9000` alone):

```
MINIO_PUBLIC_ENDPOINT=https://minio-dofi.datablu.asia
```

Restart so `api`/`jobs` read it:

```bash
cd ~/st_dofi_backend_staging
docker compose up -d --force-recreate api jobs
docker compose ps
```

Use `--force-recreate`, not `docker compose restart`: a plain restart reuses the container's existing
environment and does not re-read `env_file`.

No code or storage-config change is needed: `config/storage.yml`'s `minio_public` and
`minio_assets_public` services both already read `MINIO_PUBLIC_ENDPOINT`. Presigned URLs live 5 minutes
(`Attachments::PublicUrl::EXPIRES_IN`), so no previously issued URL outlives the switch for long.

## Step 5: Verify end to end

1. Call `GET https://api-dofi.datablu.asia/api/v1/attachments/<signed_id>` with a valid JWT and check
   that the `Location` header starts with `https://minio-dofi.datablu.asia/`.
2. Open the frontend and load an attachment (a vessel image or a company document). It should render,
   with no mixed-content warning in the Console.
3. Load something from the public bucket (e.g. a `Dictionary` `image_url`) and confirm it is also
   `https://minio-dofi.datablu.asia/...` and loads.

## Verification checklist

- [ ] DNS resolves to the server and the vhost serves `403` from MinIO over HTTPS from outside.
- [ ] The vhost uses `$http_host`, and `X-Amz-Signature` URLs return the file rather than
      `SignatureDoesNotMatch`.
- [ ] `MINIO_PUBLIC_ENDPOINT` is `https://...` in `.env` and `api`/`jobs` were recreated after.
- [ ] The `Location` header of `/api/v1/attachments/:signed_id` is `https://`.
- [ ] No mixed-content or CORS errors in the browser Console.
- [ ] Port 9010 still works (rollback path) until the new setup has run cleanly for a while.

## Rollback

Set `MINIO_PUBLIC_ENDPOINT=http://46.202.163.155:9010` back in `.env` and run
`docker compose up -d --force-recreate api jobs`. The old vhost was left untouched, so this returns to
the previous behaviour immediately.

## Cleanup (after it has been stable)

- Remove the `dofi-minio` vhost on port 9010 and close that port, so MinIO is only reachable over
  HTTPS:
  ```bash
  sudo rm /etc/nginx/sites-enabled/dofi-minio
  sudo nginx -t && sudo systemctl reload nginx
  ```
- Update the examples in `docs/minio/MINIO.md` (§ env vars and the troubleshooting table) and
  `docs/minio/MINIO-PUBLIC-PROXY-SETUP.md`, which still show `http://<server-ip>:9010`.
- Do the same for production: it needs its own subdomain and certificate, and `MINIO_PUBLIC_ENDPOINT`
  in production's `.env`. Production should never have used a plain-HTTP public endpoint.

## Common pitfalls

| Symptom | Cause |
|---|---|
| `certbot` fails with "DNS problem" / "connection refused" | The `A` record is missing or has not propagated, or port 80 is blocked |
| `403 SignatureDoesNotMatch` after the switch | Vhost uses `$host`, or `api`/`jobs` still signed with the old endpoint because they were not recreated |
| `Location` header is still `http://...` | `.env` edited but `api` not recreated, or edited on the wrong server |
| Works in `curl`, still blocked in the browser | The browser is on a cached page or the frontend hardcodes an `http://` URL |
| Browser shows a certificate warning | Certificate was issued for a different name than the one in `MINIO_PUBLIC_ENDPOINT` |
