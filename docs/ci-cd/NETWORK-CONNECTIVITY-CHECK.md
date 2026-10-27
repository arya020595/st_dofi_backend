# Network connectivity check between the servers

How to prove that the client's firewall rules ([§3 of the architecture doc](../architecture/production-4-server-architecture.md#3-network-firewall-request))
are in place, from each server, with the same commands every time. Run it before the first `db:prepare`
([checklist](PRODUCTION-DEPLOY-CHECKLIST.md) section D) and again whenever the client changes a rule. Every command is
read-only.

## Baseline, 2026-10-23 (before the client opened anything)

| From | To | Row | Result | Meaning |
|---|---|---|---|---|
| Backend | DB `10.252.8.23:5432` | 5 | `Connection refused` | Not open yet (PostgreSQL itself is listening, checked on the DB host) |
| Backend | Storage `10.252.8.13:9000` | 4 | `Connection refused` | Not open yet (MinIO itself is healthy, checked on the storage host) |
| Backend | `ghcr.io:443` | 7 | works (`HTTP/2 405` to a `HEAD`) | Open |
| Storage | `ghcr.io:443`, Docker Hub, `download.docker.com` | 8 | works | Open |
| DB | Ubuntu apt mirrors | 9 | works | Open |
| Backend | itself | | nginx answers on `:80` | Ready for row 2 |
| Backend | Registry MySQL `10.252.8.23:9139` | 12 | not checked yet | New row (the read-only ROCBN company lookup), still to be requested |

## Re-check, 2026-10-27 (from the backend server, after the client opened rows 4 and 5)

| From | To | Row | Result | Meaning |
|---|---|---|---|---|
| Backend | DB `10.252.8.23:5432` | 5 | `OPEN` | Open (was refused on 2026-10-23) |
| Backend | Storage `10.252.8.13:9000` | 4 | `OPEN` | Open (was refused on 2026-10-23) |
| Backend | `ghcr.io:443`, `pkg-containers.githubusercontent.com:443` | 7 | `OPEN` | Open |
| Backend | itself | | nginx on `:80`, `:3000` free | Ready |
| Backend | Registry MySQL `10.252.8.23:9139` | 12 | `Connection refused` | **Not open yet.** The client's table has no row for it. To be followed up with the client's management; until then only the company lookup answers `503` |

Still not checked: row 6 (BruneiID host, still TBC), and the user-facing
rows 1 to 3 (browser to frontend `4100`, backend `80`, storage `9000`). The client's own table lists web to app on
`3000` and no browser to `80` or `9000`, which differs from this design; see the checklist, section A.

## 1. Helper (paste once per session, bash)

It reports `OPEN`, `TIMEOUT` or `REFUSED` for a host and port, and needs nothing installed:

```bash
check() {  # usage: check <host> <port> "<label>"
  timeout 3 bash -c "exec 3<>/dev/tcp/$1/$2" 2>/dev/null; rc=$?
  case $rc in 0) r=OPEN;; 124) r=TIMEOUT;; *) r=REFUSED;; esac
  printf '%-22s %-8s %s\n' "$1:$2" "$r" "$3"
}
ip -4 addr | grep 'inet 10\.'          # this server's own IP: the client's rules and pg_hba.conf match on it
```

How to read it:

| Result | What it means |
|---|---|
| `OPEN` | The port is reachable. |
| `TIMEOUT` | Nothing came back: a firewall is silently dropping the traffic, or there is no rule. |
| `REFUSED` | Something answered "no" (also covers "no route to host"). If the service is known to be running on that port, a firewall is rejecting it. If nothing runs there yet (the frontend on `4100` before it is deployed), it proves nothing. |

## 2. Run these, per source server

**Backend `OGCMET001API001` (10.252.8.12)**

```bash
check 10.252.8.23 5432 "row 5: backend -> database"
check 10.252.8.13 9000 "row 4: backend -> storage (MinIO)"
check 10.252.8.23 9139 "row 12: backend -> ROCBN registry (MySQL, read-only)"
check ghcr.io 443 "row 7: backend -> GHCR"
check pkg-containers.githubusercontent.com 443 "row 7: backend -> GHCR layers"
check <BRUNEIID_HOST> 443 "row 6: backend -> BruneiID (host still TBC)"
```

**Storage `OGCMET001API002` (10.252.8.13)**

```bash
check ghcr.io 443 "row 8: storage -> GHCR"
```

**Database `OGCMPT003API001` (10.252.8.23)**

```bash
check archive.ubuntu.com 80 "row 9: database -> apt mirror"
check security.ubuntu.com 80 "row 9: database -> apt security"
```

**A user machine on the client's LAN or VPN** (a laptop, or the frontend server), for rows 1 to 3:

```bash
check 10.246.8.12 4100 "row 1: users -> frontend (REFUSED is expected until the frontend runs)"
check 10.252.8.12 80   "row 2: users -> backend nginx"
check 10.252.8.13 9000 "row 3: users -> storage (file URLs)"
```

## 3. Confirm the application layer once the ports are `OPEN`

An open port is not yet a working login. From the **backend** server:

```bash
curl -fsS -m 5 -o /dev/null -w 'storage health: %{http_code}\n' http://10.252.8.13:9000/minio/health/live     # 200
psql -h 10.252.8.23 -U dofi -d postgres -c 'select 1'      # needs: sudo apt install -y postgresql-client
```

| `psql` says | Meaning and fix |
|---|---|
| `select 1` returns `1` | Done: network, `pg_hba.conf` and the password are all right. |
| `password authentication failed for user "dofi"` | The network and `pg_hba.conf` are right; the password is wrong (reset with `\password dofi` on the DB host). |
| `no pg_hba.conf entry for host "x.x.x.x"` | The database sees the backend as `x.x.x.x`, not `10.252.8.12`. Use that address in the `pg_hba.conf` rule and in the firewall request. |
| `Connection refused` or timeout | Still the firewall (row 5). |

The registry (row 12) is checked from the application itself, so it uses the same client, account and TLS settings as
the real lookup. It is read-only: it only issues `SELECT` and `SHOW`, and never prints the password.

```bash
cd /opt/dofi && docker compose run --rm --no-deps api bin/rails rocbn:check
```

| `rocbn:check` says | Meaning and fix |
|---|---|
| `privileges  SELECT only`, exit 0 | Done: network, account, password and the table are all right. |
| `privileges  WARNING: also holds ...` | It works, but the account can do more than the lookup needs. Ask the DBA for `SELECT` on `tdd_db.sync_rocbn_hotel` only. |
| `FAILED (... Access denied ...)` | The port is open but the account or password is wrong, or the account is not allowed from `10.252.8.12`. |
| `FAILED (... Can't connect ...)` or a timeout | Still the firewall (row 12), or a wrong `ROCBN_DB_HOST` / `ROCBN_DB_PORT` in `.env`. |
| `FAILED (... plugin ...)` | The account's authentication plugin could not be negotiated: ask the DBA which one it uses. |
| `table  FAILED, ... lacks: <column>` | The registry's table no longer has a column the lookup reads: tell the backend team. |

From a **user machine**, a public-bucket object opens without a login (after the first `db:prepare` has seeded images):
`curl -I http://10.252.8.13:9000/dofi-production-public/<object>` returns `200`.

## 4. If a row is still closed

Send the client's team the output of the failing `check` lines together with the source server's `ip -4 addr` line.
That shows the exact source IP, the destination, the port and whether it is dropped (`TIMEOUT`) or rejected
(`REFUSED`). Rows 4 and 5 are the blockers for section D.

## 5. After everything is `OPEN`

Continue the [checklist](PRODUCTION-DEPLOY-CHECKLIST.md) from C3 (backend preparation), then section D.
