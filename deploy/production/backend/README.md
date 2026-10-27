# Backend server: Rails API in Docker, behind nginx

The Rails `api` and `jobs` run as Docker containers from the private GHCR image; the host's nginx is the only public
entry. Host `OGCMET001API001`, 10.252.8.12. **Releases are pulled by hand:** GitHub Actions builds, tests and pushes the
image, and an engineer on the server (through Delinea) pulls it. GitHub never connects to this server; every connection
from it is outbound (`ghcr.io`, BruneiID). A fallback that builds the image on the server is in [section 11](#11-fallback-build-on-the-server-approach-b). The tick-box version of this runbook is section C3 of
[`PRODUCTION-DEPLOY-CHECKLIST.md`](../../../docs/ci-cd/PRODUCTION-DEPLOY-CHECKLIST.md).

```
frontend server --HTTP :3000--> nginx --127.0.0.1:3000--> api container --> PostgreSQL  <DB_IP>:5432
                                                           jobs container --> MinIO       <STORAGE_IP>:9000
```

Why this shape: the frontend (`http://10.246.8.12:4100`) is a different origin from the API, so the browser sends
CORS requests. Rails answers them (`CORS_ORIGINS`), and nginx only forwards. Rails is published on `127.0.0.1` so that
Rails itself is not reachable from the network (a Docker-published port bypasses `ufw`). What the network sees on
`10.252.8.12:3000` is nginx, which the host firewall allows only from the frontend server (step 6). Browsers never call
this host directly: they reach the frontend, which proxies `/api` and `/cable` here.

Needs: `sudo` on this host, the database server done ([`../database/README.md`](../database/README.md)), the storage
server done ([`../storage/`](../storage/)), and the client's firewall rules in place.
Replace the placeholders: `<BACKEND_IP>` 10.252.8.12, `<DB_IP>` 10.252.8.23, `<STORAGE_IP>` 10.252.8.13,
`<FE_ORIGIN>` `http://10.246.8.12:4100` (confirm the frontend IP with the client; see the open questions in
[the architecture doc](../../../docs/architecture/production-4-server-architecture.md#7-questions-for-the-client)).

> **Port choice (decided 2026-10-27).** The client's firewall table already opens `10.246.8.12` to `10.252.8.12` on TCP
> **3000**, so nginx listens on `10.252.8.12:3000` as well as on 80 (see [`nginx/dofi-api.conf`](nginx/dofi-api.conf)). Rails
> stays published on `127.0.0.1:3000`; the two bind different addresses, so nothing else changes. The frontend calls
> `http://10.252.8.12:3000`. Port 80 stays for local checks and is not requested from the client.

## 0. Look first (read-only)

```bash
lsb_release -a; free -h; nproc; df -h                    # Ubuntu 24.04 expected; RAM, CPU, disk for sizing
docker --version; docker compose version                 # both must print a version
nginx -v; systemctl is-active nginx ufw firewalld
ls /etc/nginx/sites-enabled                              # only `default` expected; any other site is not ours: leave it
sudo ss -lntp | grep -E ':(80|3000)\b'                   # 80 = nginx; 3000 must be free
nc -vz <DB_IP> 5432; nc -vz <STORAGE_IP> 9000            # "succeeded" needs firewall rows 4 and 5 and the other two servers up
curl -sI https://ghcr.io | head -1                       # outbound to the image registry (firewall row 7)
curl -sI https://pkg-containers.githubusercontent.com | head -1   # where the image layers are downloaded from
```

A failing `nc` or `curl` is a firewall or server-order problem, not something to fix in this runbook: ask the client
(checklist section A) or finish the database and storage servers first.

## 1. Deploy user and `/opt/dofi`

This is the user that runs every release (`docker compose ...`) in the Delinea terminal.

```bash
sudo usermod -aG docker "$USER"        # log out and back in afterwards; docker group members are root-equivalent
docker info > /dev/null && echo docker-ok
sudo mkdir -p /opt/dofi/nginx && sudo chown -R "$USER": /opt/dofi
```

## 2. Log in to the image registry

The image `ghcr.io/arya020595/st_dofi_backend` is private. Use a GitHub token with only `read:packages`; typing it with
`read -s` keeps it out of the shell history.

```bash
read -rs GHCR_TOKEN && echo "$GHCR_TOKEN" | docker login ghcr.io -u <github-user> --password-stdin; unset GHCR_TOKEN
```

Docker stores the credential in `~/.docker/config.json`, and nothing else renews it: this token is what every release
uses. Write its expiry date in the team's notes; when it expires, `docker compose pull` says `unauthorized` and you
repeat this step with a new token.

## 3. Put the files and the `.env` in place

Three files from this folder go to `/opt/dofi` (the paths below are relative to the repo):

| From the repo | To the server |
|---|---|
| `deploy/production/backend/docker-compose.yml` | `/opt/dofi/docker-compose.yml` |
| `deploy/production/backend/.env.example` | `/opt/dofi/.env.example` |
| `deploy/production/backend/nginx/dofi-api.conf` | `/opt/dofi/nginx/dofi-api.conf` |

With plain SSH: `scp deploy/production/backend/docker-compose.yml deploy/production/backend/.env.example <user>@<BACKEND_IP>:/opt/dofi/`
(and the vhost into `/opt/dofi/nginx/`). Through the Delinea terminal, where `scp` may not work, open each file in the
repo and paste it into `nano /opt/dofi/<file>`; they are short.

Then create the real `.env`. It is never committed. The compose file is not updated automatically either: when it
changes in the repo, paste the new version into `/opt/dofi/docker-compose.yml` by hand before the next release.

```bash
cd /opt/dofi && cp .env.example .env && chmod 600 .env && nano .env
```

| Variable | Value |
|---|---|
| `RAILS_MASTER_KEY` | The content of `config/master.key` from the repo owner's checkout. Without it the app does not boot. |
| `DEVISE_JWT_SECRET_KEY` | `openssl rand -hex 32`. Changing it later signs every user out. |
| `FORCE_SSL` | `false` until there is a certificate (otherwise logins loop on a redirect to HTTPS). |
| `DATABASE_HOST`, `DATABASE_PASSWORD` | `<DB_IP>` and the `dofi` role's password (database runbook, step 3). `DATABASE_USERNAME` stays `dofi`. |
| `CORS_ORIGINS`, `CABLE_ALLOWED_ORIGINS` | `<FE_ORIGIN>`: scheme, host and port exactly as the browser shows it, no trailing slash. Both variables, same value (CORS does not cover the WebSocket upgrade). |
| `MINIO_ENDPOINT`, `MINIO_PUBLIC_ENDPOINT` | Both `http://<STORAGE_IP>:9000`. |
| `MINIO_BUCKET`, `MINIO_ASSETS_BUCKET` and the four access/secret keys | Copied from the storage server's `.env`. |
| `BRUNEIID_*` | From the client. `BRUNEIID_REDIRECT_URI` must match, character for character, the URI registered at BruneiID (a mismatch makes every login callback fail with `422 invalid_request`). |

Check it before starting. `-q` prints nothing on success; plain `docker compose config` would print the secrets.

```bash
docker compose config -q && echo env-ok
```

## 4. First start

```bash
cd /opt/dofi
docker compose pull
docker compose run --rm api bin/rails db:prepare     # creates the four databases and seeds reference data; needs the DB and MinIO up
docker compose up -d
docker compose ps                                    # api and jobs: Up
docker compose logs --tail 50 api jobs               # no stack traces
curl -i http://127.0.0.1:3000/up                     # 200; works only from this host
```

If `pull` says the `:production` tag is not found, the image was never built: merging to `main` runs the workflow
"CD Production", whose `build-and-push` job pushes `:production` and `:<git sha>` to GHCR. Nothing reaches this server
from it.

## 5. nginx in front of the API

```bash
sudo cp /opt/dofi/nginx/dofi-api.conf /etc/nginx/sites-available/dofi-api
sudo ln -sf /etc/nginx/sites-available/dofi-api /etc/nginx/sites-enabled/dofi-api
sudo rm -f /etc/nginx/sites-enabled/default          # only if `default` was the only other site (step 0): it also claims port 80
sudo nginx -t && sudo systemctl reload nginx         # reload keeps connections; never skip the -t
curl -i http://127.0.0.1/up                          # 200, header `Server: nginx` without a version
```

What the file does, so you can change it safely:

- `location /cable` upgrades the connection to a WebSocket (`Upgrade`/`Connection` headers) and keeps idle sockets open for an hour.
- `Host $http_host`, not `$host`: `$host` drops the port ([the same pitfall as for MinIO](../../../docs/minio/MINIO-PUBLIC-PROXY-SETUP.md)).
- `X-Forwarded-For $remote_addr` **overwrites** the header instead of appending. Rack::Attack throttles per IP and treats private
  ranges as trusted proxies, so a client-supplied `X-Forwarded-For` would otherwise let anyone dodge the limits.
- `client_max_body_size 12m`: the app rejects files over 10 MB; nginx's own default of 1 MB would reject them first.
- CORS headers are **not** set here. Rails sets them; adding them in nginx too produces duplicate headers that browsers refuse.

The vhost is not part of CD: if it changes in the repo, copy it again and `nginx -t && sudo systemctl reload nginx`.

## 6. Host firewall

**This host runs `firewalld`** (zone `public`, default target). It only allows what is listed, and rejects everything else
with `ICMP admin prohibited`, so the frontend got "No route to host" / "Couldn't connect" even though nginx was up and the
client's network rule was open. `iptables -S` and `ufw status` do not show it: the rules live in the nft table
`inet firewalld`. Check with `sudo firewall-cmd --list-all`. The ports already listed there (4119, 4120, 4122, 5274, 443,
14118) belong to other things on this host: leave them.

Allow only the frontend server to reach port 3000, now and permanently. **Do not run `firewall-cmd --reload`** for this: it
can wipe Docker's network rules until Docker is restarted; adding to the runtime and the permanent config separately avoids it.

```bash
RULE='rule family="ipv4" source address="10.246.8.12" port port="3000" protocol="tcp" accept'
sudo firewall-cmd --add-rich-rule="$RULE"
sudo firewall-cmd --permanent --add-rich-rule="$RULE"
sudo firewall-cmd --list-rich-rules; sudo firewall-cmd --permanent --list-rich-rules   # both show the rule
```

Undo: the same commands with `--remove-rich-rule`. If `ufw` is ever the active firewall instead, allow SSH first, then
`sudo ufw allow from 10.246.8.12 to any port 3000 proto tcp`.

## 7. Verify frontend to backend

Run these from another machine on the users' network, the frontend server (10.246.8.12): only that address is allowed on port 3000 (step 6). They show what a browser will meet.

```bash
curl -i http://<BACKEND_IP>:3000/up                       # 200

# CORS preflight: what the browser sends before a cross-origin POST (login)
curl -i -X OPTIONS http://<BACKEND_IP>:3000/api/v1/auth/sign_in \
  -H 'Origin: <FE_ORIGIN>' -H 'Access-Control-Request-Method: POST' \
  -H 'Access-Control-Request-Headers: content-type,authorization'
# expect: HTTP 200 and `access-control-allow-origin: <FE_ORIGIN>`. No such header: CORS_ORIGINS does not match.

# WebSocket handshake (curl exits with a timeout after 5 s; the 101 line is what matters)
curl -i -N --max-time 5 http://<BACKEND_IP>:3000/cable \
  -H 'Connection: Upgrade' -H 'Upgrade: websocket' -H 'Sec-WebSocket-Version: 13' \
  -H 'Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==' -H 'Origin: <FE_ORIGIN>'
# expect: HTTP/1.1 101 Switching Protocols. 404 "Page not found": CABLE_ALLOWED_ORIGINS does not match.
```

Then log in from the frontend itself and check the browser console for CORS or WebSocket errors.

Give the frontend team:

| What | Value |
|---|---|
| API base URL | `http://<BACKEND_IP>:3000` (REST under `/api/v1`) |
| WebSocket | `ws://<BACKEND_IP>:3000/cable?token=...` (the token comes from the API, as today) |
| Health check | `http://<BACKEND_IP>:3000/up` |

## 8. Operate

```bash
cd /opt/dofi
docker compose logs -f --tail 100 api jobs           # app logs (JSON, request ids)
sudo tail -f /var/log/nginx/error.log                # 502 and upstream errors
docker compose up -d                                 # after editing .env: recreates only what changed
docker compose run --rm api bin/rails console        # console, production data: careful
```

- **Release:** after a push to `main`, wait for the green "Build & Push GHCR" job (Slack says "Manual deployment required"), then on the server: `docker compose pull && docker compose run --rm api bin/rails db:prepare && docker compose up -d --wait && curl -fsS http://127.0.0.1:3000/up && docker image prune -f`. To run a specific build, set `IMAGE_TAG=<git sha>` in `.env` first. `api` restarts for a few seconds.
- **Roll back:** set `IMAGE_TAG=<previous git sha>` in `/opt/dofi/.env`, then `docker compose up -d`. Database migrations are not rolled back, so keep them compatible with the previous release.
- **Disk:** `docker image prune -f` after each release removes the old image layers.

## 9. Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| `502 Bad Gateway` from nginx | `api` is not running or is still booting. `docker compose ps`, `docker compose logs api`, `curl http://127.0.0.1:3000/up`. |
| Container is `Up` but `:3000/up` fails | Boot error: wrong or missing `RAILS_MASTER_KEY`, or the database is unreachable. Read `docker compose logs api`. |
| Browser CORS error | The frontend origin is not exactly in `CORS_ORIGINS` (port, `http` vs `https`, trailing slash). Re-run the preflight from step 7, fix `.env`, `docker compose up -d`. |
| WebSocket closes at once, log says `Request origin not allowed` | Origin missing in `CABLE_ALLOWED_ORIGINS`. |
| `413 Request Entity Too Large` | Upload over 12 MB. The app limits are 2 to 10 MB; raise `client_max_body_size` only together with the model limit. |
| nginx shows its welcome page | The `default` site is still enabled; step 5. |
| `429 Too Many Requests` for everyone at once | All requests look like one IP. Check `proxy_set_header X-Forwarded-For $remote_addr;` is in both locations and nginx was reloaded. |
| Cannot reach `<BACKEND_IP>:3000` from the frontend, `curl 127.0.0.1` works | Check on this host with `sudo tcpdump -ni any 'tcp port 3000 and host 10.246.8.12' -c 5` while the frontend runs `curl`. A SYN followed by `ICMP ... admin prohibited` sent by this host: `firewalld` (step 6). No SYN at all: the client's network firewall (checklist section A). |
| `docker compose pull`: `unauthorized` | The GitHub token from step 2 expired or was revoked. Repeat step 2 with a new `read:packages` token. |
| Login redirects or loops to HTTPS | `FORCE_SSL` must be `false` while there is no certificate. |
| File links return `403 SignatureDoesNotMatch` | `MINIO_PUBLIC_ENDPOINT` differs from the address the browser actually uses. |

## 10. Later: a domain and TLS

When the client provides a domain and a certificate: add a `listen 443 ssl` server block with the same two `location`
blocks and `X-Forwarded-Proto https`, redirect port 80 to it (keep `/up` on 80 for monitors), set `FORCE_SSL=true`, change
`CORS_ORIGINS` and `CABLE_ALLOWED_ORIGINS` to `https://` origins (the WebSocket becomes `wss://`), and set `APP_HOSTS` to the
domain. MinIO must be HTTPS too, or browsers block its file links as mixed content. Port 443 then replaces 80 in the firewall
request. Plan: [architecture doc, section 6](../../../docs/architecture/production-4-server-architecture.md#6-later).

## 11. Fallback: build on the server (Approach B)

Only when CI or `ghcr.io` is not working and a fix cannot wait. The server clones the repository and builds the same
image itself, so it needs the extra outbound access the client whitelisted for it (GitHub over `ssh.github.com:443`,
Docker Hub, Debian mirrors on 80 and 443, RubyGems). Everything else (`.env`, nginx, database, MinIO) is unchanged.

One-time setup, as the deploy user:

```bash
# a read-only GitHub deploy key for this repo (repo Settings, Deploy keys, leave "Allow write access" off)
ssh-keygen -t ed25519 -f ~/.ssh/dofi_github_readonly -N ""
cat ~/.ssh/dofi_github_readonly.pub                          # paste into the repo's Deploy keys
cat >> ~/.ssh/config <<'EOF'
Host github.com
  HostName ssh.github.com
  Port 443
  User git
  IdentityFile ~/.ssh/dofi_github_readonly
  IdentitiesOnly yes
EOF
chmod 600 ~/.ssh/config
ssh -T git@github.com                                        # "Hi <repo>! You've successfully authenticated"
git clone git@github.com:arya020595/st_dofi_backend.git /opt/dofi/src
cp /opt/dofi/src/deploy/production/backend/docker-compose.build.yml /opt/dofi/
```

Each fallback release:

```bash
cd /opt/dofi/src && git pull --ff-only && git log -1 --oneline     # check the commit is the one you mean to ship
cd /opt/dofi
docker compose -f docker-compose.yml -f docker-compose.build.yml build
docker compose -f docker-compose.yml -f docker-compose.build.yml run --rm api bin/rails db:prepare
docker compose -f docker-compose.yml -f docker-compose.build.yml up -d --wait
curl -fsS http://127.0.0.1:3000/up
```

The override [`docker-compose.build.yml`](docker-compose.build.yml) swaps the pulled image for the locally built
`dofi-backend:local` and forbids pulling. Every `docker compose` command must carry both `-f` flags while you are on the
fallback, or Compose goes back to the GHCR image. To return to normal releases: `docker compose pull && docker compose up -d`
(without the override). The fallback skips the CI test job, so run the suite or at least `bin/ci` elsewhere first if time allows.
