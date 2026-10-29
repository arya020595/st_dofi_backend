# Production deploy checklist (4 servers)

Step-by-step to-do for putting the backend, file storage and database on the client's servers, reached by IP
over plain HTTP (no domain or TLS yet; the backend sits behind nginx on port 3000). Every tick below has its commands
inline; the explanations are in [`deploy/README.md`](../../deploy/README.md), the
[backend runbook](../../deploy/production/backend/README.md) and the [database runbook](../../deploy/production/database/README.md);
the design is in [`production-4-server-architecture.md`](../architecture/production-4-server-architecture.md). Tick the boxes in order.

## Go-live readiness: staff sign-in through Active Directory (updated 2026-10-28)

```text
Application implementation:       [x] LOCAL VERIFIED      branch feat/active-directory-login, PR #101 open; not merged, not deployed
Automated test suite:             [x] COMPLETE            929 runs, 0 failures, 0 errors, 0 skips (2026-10-28)
Simulated AD integration:         [x] LOCAL VERIFIED      real LDAPS bind against a local simulator, 29 end-to-end tests
Real AD connectivity:             [ ] NOT TESTED          PENDING INFRASTRUCTURE (DNS, port, firewall, certificate)
Real AD authentication:           [ ] NOT TESTED          PENDING CLIENT (test account, bind format)
Production security readiness:    [ ] BLOCKED             sections 3 and 4 below
Production deployment approval:   [ ] PENDING CLIENT

Overall Go-Live Decision: NO-GO
```

**Why NO-GO.** Staff can only sign in through the directory, and nothing has ever been sent to the real one. Until a
test account has bound successfully from the production backend container, over a verified certificate, the staff
sign-in is unproven. Fishermen and Jetty Managers (BruneiID) are not affected.

How to read this: `LOCAL VERIFIED` means it passed against code or the **local simulator only** (a test stand-in
that proves our side of the protocol, not the client's directory). Nothing marked `[x]` here has been tested against the
real Active Directory. Evidence is a test class under `test/` or a command that was run; run them with
`bin/rails test test/integration/active_directory` (the simulator needs no setup). Detail and diagrams:
[`docs/active-directory/`](../active-directory/README.md), runbook:
[`active-directory-login.md`](../registration/active-directory-login.md).

Status words: `[x] COMPLETE` verified with evidence · `[x] LOCAL VERIFIED` simulator or unit only · `[ ] PENDING CLIENT` ·
`[ ] PENDING INFRASTRUCTURE` · `[ ] NOT TESTED` · `[ ] BLOCKED` · `[ ] FAILED`.

### 1. Application readiness

| Item | Status | Env | Evidence | Owner | Dependency | Last verified |
|---|---|---|---|---|---|---|
| Rails API running on the production backend (the release **before** the AD change) | [x] COMPLETE | Production | Section D of this file: `api`/`jobs` healthy, 2026-10-27 | Engineering | none | 2026-10-27 (not re-checked) |
| AD release merged, image built, deployed | [ ] NOT TESTED | Production | PR #101 is open; later CA-trust and end-to-end work is uncommitted | Engineering | review and merge, then section E | n/a |
| Production `.env` for AD (`AD_MODE=ldap`, `AD_*`) | [ ] PENDING CLIENT | Production | The app refuses to boot without `AD_MODE`; values are unconfirmed (section 3) | Engineering + AD Team | confirmed host, port, bind format | n/a |
| Local user eligibility (active, not discarded) | [x] LOCAL VERIFIED | Local | `ActiveDirectory::SignInTest` ("valid AD credentials cannot override an inactive, suspended or discarded local account") | Engineering | none | 2026-10-28 |
| JWT issue, sign-out and revocation | [x] LOCAL VERIFIED | Local | `ActiveDirectory::SessionAndAccessTest`, `SessionsTokenRevocationTest` | Engineering | none | 2026-10-28 |
| Authorization comes from local roles | [x] LOCAL VERIFIED | Local | `SessionAndAccessTest` ("permissions are the local role's"); `bin/rbac-lint` passed | Engineering | none | 2026-10-28 |
| Security logging (`ad.login`, `ad.directory_unavailable`, no secrets) | [x] LOCAL VERIFIED | Local | `SignInTest` (log test), `FailureModesTest` (category logged, nothing sensitive) | Engineering | none | 2026-10-28 |
| Quality checks | [x] COMPLETE | Local | `bin/rails test` 929 runs 0 failures; `bin/rubocop` 730 files clean; `bin/rbac-lint` passed; `bin/brakeman` 0 warnings; `bin/bundler-audit` none | Engineering | none | 2026-10-28 |

### 2. Active Directory integration (code and simulator)

| Item | Status | Env | Evidence | Owner | Dependency | Last verified |
|---|---|---|---|---|---|---|
| AD implementation (Warden strategy, `OfficerLogin`, `LdapAuthenticator`) | [x] LOCAL VERIFIED | Local | `test/services/authentication/`, `test/integration/active_directory/` | Engineering | none | 2026-10-28 |
| Mock directory (local, staging) | [x] LOCAL VERIFIED | Local | `SessionsSharedMockPasswordTest`, `SessionAndAccessTest` ("mock directory still works") | Engineering | staging `.env` needs the mock password | 2026-10-28 |
| Real LDAP mode against a local simulator (TCP + TLS + LDAP simple bind through `POST /api/v1/auth/sign_in`) | [x] LOCAL VERIFIED | Local | `SignInTest`, `FailureModesTest`, `SessionAndAccessTest` (29 tests) | Engineering | none | 2026-10-28 |
| Valid bind returns 200 + JWT; both bind formats (`MPRT\name`, `name@MPRT.EG.GOV.BN`) | [x] LOCAL VERIFIED | Local | `SignInTest` first test | Engineering | which format the real AD accepts is unconfirmed | 2026-10-28 |
| Wrong password: 401, no JWT, no local fall back | [x] LOCAL VERIFIED | Local | `SignInTest` | Engineering | none | 2026-10-28 |
| Disabled or locked account (simulated as LDAP result 49): 401, same body as a wrong password | [x] LOCAL VERIFIED | Local | `SignInTest`; proves our handling only, not AD's lockout policy | Engineering | approved real test accounts | 2026-10-28 |
| TLS certificate verification (untrusted CA, expired, wrong host name, invalid CA file) | [x] LOCAL VERIFIED | Local | `FailureModesTest`; with `VERIFY_PEER` replaced by `VERIFY_NONE` 5 of these fail | Engineering | none | 2026-10-28 |
| System CA store used when `AD_CA_FILE` is empty | [x] LOCAL VERIFIED | Local | `LdapAuthenticatorTlsTest` (child process with `SSL_CERT_FILE`); the dev image holds 148 CAs | Engineering | whether the real AD certificate chains to one | 2026-10-28 |
| Optional `AD_CA_FILE`; an invalid one is a 503, never a fall back | [x] LOCAL VERIFIED | Local | `LdapAuthenticatorTlsTest`, `FailureModesTest`, `DirectoryConfigTest` | Engineering | CA file only if the AD team supplies one | 2026-10-28 |
| AD unavailable, hang-up and silent server: 503 within the timeouts, rest of the API works | [x] LOCAL VERIFIED | Local | `FailureModesTest` | Engineering | none | 2026-10-28 |
| Failover (first server hangs up, or presents a refused certificate); a refused password is bound once. An unresolvable first host name is not simulated: it depends on the local DNS and made the test flaky | [x] LOCAL VERIFIED | Local | `FailureModesTest` (server-side bind counts) | Engineering | real multi-server failover is untested | 2026-10-28 |
| JWT lifecycle with LDAP sign-ins (sign-out, deactivate, suspend, discard, username change, re-enable) | [x] LOCAL VERIFIED | Local | `SessionAndAccessTest` | Engineering | none | 2026-10-28 |
| Jetty Manager, Fisherman and BruneiID flows unchanged | [x] COMPLETE | Local | Full suite green; `SessionAndAccessTest` (they never reach the directory) | Engineering | none | 2026-10-28 |
| Hostile input (empty, missing, NUL byte, oversized, malformed payload), throttling (429), password never logged | [x] LOCAL VERIFIED | Local | `SignInTest`. The test env uses a null cache, so the 429 test installs an in-memory store. **Found and fixed:** a NUL byte in a username or in a local password made Devise's own lookup raise (HTTP 500); the strategy now refuses it with 401 | Engineering | none | 2026-10-28 |

### 3. Active Directory infrastructure (all of this is the real environment, and none of it is tested)

Candidate servers, **not confirmed**: `prtauthpro1.mprt.eg.gov.bn` (10.112.12.13), `prtauthpro2.mprt.eg.gov.bn`
(10.112.12.17), `prtauthpro3.mprt.eg.gov.bn` (10.240.64.16); candidate port TCP `3269`. The IPs are for the firewall
only; the application rejects IPs as `AD_HOST` because the certificate name is verified.

| Item | Status | Env | Evidence | Owner | Dependency | Last verified |
|---|---|---|---|---|---|---|
| AD DNS domain `MPRT.EG.GOV.BN`, NetBIOS `MPRT` | [ ] PENDING CLIENT | Production | Given in the client's initial information; not checked against the directory | AD Team | written confirmation | n/a |
| The three FQDNs | [ ] PENDING CLIENT | Production | Expected names only | AD Team | confirm names and certificate SANs | n/a |
| DNS resolution from the backend container | [ ] NOT TESTED | Production | Runbook step A | Infrastructure | server access (Delinea) | n/a |
| LDAPS port confirmed (3269 Global Catalog, or 636) | [ ] PENDING CLIENT | Production | The firewall document lists 3268/3269; LDAPS operation is unconfirmed | AD Team | confirm per server | n/a |
| Firewall backend to AD hosts and port | [ ] PENDING INFRASTRUCTURE | Production | Runbook step B | Infrastructure | rule requested and opened | n/a |
| TLS chain verified against the system store | [ ] NOT TESTED | Production | Runbook step C | Infrastructure | reachability | n/a |
| Certificate host name verified | [ ] NOT TESTED | Production | Runbook step C | Infrastructure | reachability | n/a |
| CA file needed? (AIMS/TIMS reportedly needed none) | [ ] PENDING CLIENT | Production | Answered by step C; if needed the AD team supplies the CA PEM | AD Team | step C result | n/a |
| Bind username format (`netbios` or `upn`) | [ ] PENDING CLIENT | Production | `AD_BIND_FORMAT` stays configurable | AD Team | test with the account below | n/a |
| Dedicated AD test account received securely (plus a disabled and a locked one) | [ ] PENDING CLIENT | Production | none yet | AD Team | secure hand-over | n/a |
| Real bind with valid credentials | [ ] NOT TESTED | Production | Runbook step D, once | Engineering | all rows above | n/a |
| Real bind with invalid credentials (approved test account, once) | [ ] NOT TESTED | Production | Never repeat: AD locks accounts | Engineering + AD Team | approval | n/a |
| Real disabled/locked account handling | [ ] NOT TESTED | Production | Simulated only so far | AD Team | approved accounts | n/a |
| Real multi-server failover | [ ] NOT TESTED | Production | Simulated only so far | Engineering + Infrastructure | approval | n/a |

### 4. Production security

| Item | Status | Env | Evidence | Owner | Dependency | Last verified |
|---|---|---|---|---|---|---|
| TLS verification cannot be bypassed | [x] LOCAL VERIFIED | Local | `LdapAuthenticatorTlsOptionsTest` (source scan for `VERIFY_NONE` and similar) and the `VERIFY_NONE` mutation above | Engineering | none | 2026-10-28 |
| No local password fallback for DoFi Officers | [x] LOCAL VERIFIED | Local | `SignInTest`, `FailureModesTest`, `UserDirectoryTest`; staff store no password | Engineering | migration `BlankStaffEncryptedPasswords` runs on the first deploy (one way, not yet run on production: back up first, section G) | 2026-10-28 |
| Mock AD cannot run in production | [x] LOCAL VERIFIED | Local | `DirectoryConfigTest` (boot refuses), `DeploymentEnvironmentTest` (compose files). Not yet seen on the real server | Engineering | deploy the AD release | 2026-10-28 |
| No demo accounts with known passwords on production | [ ] BLOCKED | Production | New seeds skip them (`DemoSeedsProductionGuardTest`), but the production database still holds the demo rows from 2026-10-27 | Engineering | end of dummy-data testing, then the reset in "After testing" | 2026-10-27 |
| Secrets stored securely (no committed values) | [x] LOCAL VERIFIED | Local | `DeploymentEnvironmentTest` scans committed files; production `.env` handling is not audited | Engineering | review of the server `.env` permissions | 2026-10-28 |
| Sensitive values filtered from logs | [x] LOCAL VERIFIED | Local | `SignInTest` (log test), `FailureModesTest` | Engineering | none | 2026-10-28 |
| Authentication errors mapped safely (identical 401, generic 503) | [x] LOCAL VERIFIED | Local | `SignInTest` (identical bodies) | Engineering | none | 2026-10-28 |
| User revocation behaviour | [x] LOCAL VERIFIED | Local | `SessionAndAccessTest`, `UserTokenRevocationTest` | Engineering | none | 2026-10-28 |
| Superadmin mapped to a real AD username | [ ] PENDING CLIENT | Production | `admin:assign_ad_username` is ready; the real name is missing | Client | the superadmin's AD name | n/a |
| Access controls and audit logs reviewed on the server | [ ] NOT TESTED | Production | none | Engineering + Security | deploy | n/a |

### 5. Deployment and operational readiness

| Item | Status | Env | Evidence | Owner | Dependency | Last verified |
|---|---|---|---|---|---|---|
| Required production variables verified (`AD_MODE`, `AD_HOST`, `AD_PORT`, `AD_NETBIOS_DOMAIN`, `AD_DNS_DOMAIN`, `AD_BIND_FORMAT`, optional `AD_CA_FILE`, `ADMIN_AD_USERNAME`) | [ ] PENDING CLIENT | Production | Candidate values are in `deploy/production/backend/.env.example` | Engineering | section 3 | n/a |
| Production image built and validated | [ ] NOT TESTED | Production | Built by CI on merge to `main` | Engineering | PR #101 merged | n/a |
| Backend connectivity from the deployment environment | [ ] NOT TESTED | Production | Database, MinIO and ROCBN proven 2026-10-27 (section C); AD not tried | Infrastructure | section 3 | 2026-10-27 (non-AD) |
| Database migration for the AD release | [ ] NOT TESTED | Production | `BlankStaffEncryptedPasswords` is tested locally only | Engineering | backup taken first | n/a |
| Health checks | [x] COMPLETE | Production | `api` and `jobs` healthy (pre-AD release), section D | Engineering | recheck after the AD release | 2026-10-27 |
| Backup and rollback | [ ] NOT TESTED | Production | Sections G and H. Rolling back the code does not bring back local staff passwords | Engineering | backup before the migration | n/a |
| Restart procedure | [x] COMPLETE | Production | Section E, used 2026-10-27 | Engineering | none | 2026-10-27 |
| Monitoring and error logging | [ ] NOT TESTED | Production | Sentry works (2026-10-27); no alert on `ad.directory_unavailable` yet | Engineering | alert rule | n/a |
| Incident handling for an AD outage | [ ] NOT TESTED | Production | Written in the runbook ("Emergency access"); never rehearsed; no in-app bypass by design | Engineering + Client | break-glass decision | n/a |
| Final UAT sign-off | [ ] PENDING CLIENT | Production | none | Client | real AD verification | n/a |
| Production deployment approval | [ ] PENDING CLIENT | Production | none | Client | all of the above | n/a |

### Go-live blockers

1. Confirmed AD host names, port, bind format, and whether a CA file is needed (AD Team).
2. Firewall from the backend server to the AD hosts (Infrastructure).
3. Real DNS, TCP, TLS and bind checks passing from the backend container (runbook steps A to D).
4. A dedicated AD test account, and the superadmin's real AD username (Client).
5. The production database cleared of demo accounts, and a backup taken before the one-way migration.
6. UAT sign-off and deployment approval (Client).

Servers (hostname, IP, role):

| Placeholder | Value | Server |
|---|---|---|
| `<BACKEND_IP>` | 10.252.8.12 | `OGCMET001API001`: nginx + Rails `api` + `jobs` |
| `<STORAGE_IP>` | 10.252.8.13 | `OGCMET001API002`: MinIO |
| `<DB_IP>` | 10.252.8.23 | `OGCMPT003API001`: PostgreSQL 16 (native) |
| `<FE_ORIGIN>` | `http://10.246.8.12:4100` | `OGCMET001WPD001`: frontend (confirm the IP, see section A) |

> **How releases work (the client's "Approach A").** A push or merge to `main` runs
> [`cd-production.yml`](../../.github/workflows/cd-production.yml): tests, then builds the image and pushes it to
> `ghcr.io`. It does **not** touch any server, because GitHub cannot reach the client's private network (the SSH deploy
> job is switched off). A person then pulls the new image on the backend server through Delinea: section E. Merging to
> `main` is therefore safe at any time. The compose file publishes the API on `127.0.0.1` only, so users reach it through
> nginx (section D).

## Progress (last updated 2026-10-27)

| Area | State |
|---|---|
| Database server (C1) and storage server (C2) | Set up earlier. Backend to database `5432` and backend to MinIO `9000` are open and **proven**: `db:prepare` created the four databases and uploaded 17 files to MinIO. |
| Backend server prepared (C3) | Done: Docker group, `/opt/dofi`, GHCR login, the three files (checksums match), `.env` filled and validated. `SENTRY_DSN` is set and tested (2026-10-27: an event reached Sentry); `BRUNEIID_*` is empty (not supplied yet); `ROCBN_DB_USERNAME=stuser`. |
| First run (D) | **Done 2026-10-27:** `pull`, `db:prepare`, `up -d --wait` (`api` and `jobs` healthy, image from `main` with the file relay), nginx vhost installed and the Ubuntu `default` site disabled, `rocbn:check` passes (185,324 rows). Frontend to backend works on **`http://10.252.8.12:3000`**: `/up` 200, CORS preflight allows `http://10.246.8.12:4100`, `/cable` upgrades (101). It needed nginx to listen on `10.252.8.12:3000` (and only there, no port 80) and a `firewalld` rich rule on the App server (runbook step 6); it was not the client's network. |
| Seed data | **Decided 2026-10-27: keep the demo data for testing on production, with dummy data only.** The demo accounts still have the default password `ChangeMe123!` (seeded by `db:prepare`, see the warning in section D); change at least `admin@dofi.gov.bn` now, and **reset the databases and change every seeded password before any real data goes in** (to do item 3 below). |
| Firewall, to request from the client | **Nothing left to request for the first round.** `9139` (ROCBN) is open and proven. Web to App `3000` is the client's own rule and works (the block was `firewalld` on our server, fixed). Users to storage `9000` is **not** requested: browsers reach only the Web server. BruneiID `443` waits for its hostname. **To ask the MySQL owner:** `stuser` holds `ALL PRIVILEGES` and may log in from any host (`rocbn:check` warns); the app only needs `SELECT` on `tdd_db.sync_rocbn_hotel`. |
| AD (LDAP over TLS) | **Needed since staff sign in through Active Directory:** TCP `3269` (or the port the AD team confirms) from this backend server to the AD hosts. The app will not boot on production until `AD_MODE=ldap` is set; follow the cut-over in `docs/registration/active-directory-login.md`. |
| Not needed | MinIO console `9001` (not published). |
| File viewing (decision) | **Decided 2026-10-27: relay files through Rails.** The FE server may not reach storage either, and it proxies `/api` to the BE. Code is on branch `feat/relay-attachments` (tests, rubocop, rbac-lint, brakeman green; production route table has no Active Storage routes), **not yet merged, built or deployed**. The first deploy is not blocked: start the stack with the current image; until the relay image ships, testers can upload but not view files. Still to do: FE loader for Dictionary images, FE nginx proxy, FE to BE firewall port, run `dictionaries:migrate_images_to_minio` only if old blobs must move. |
| Upload regression (2026-10-27) | Uploads re-tested after the relay change: vessel images, company documents, Dictionary create and update, spoofed type rejected, and an upload-then-fetch round trip. Full suite 776 runs, 0 failures (3 unrelated ROCBN errors). Not run against a real MinIO; verify one upload and one view on the App server after deploy. Record: [`UPLOAD-REGRESSION-2026-10-27.md`](../minio/UPLOAD-REGRESSION-2026-10-27.md). |
| File viewing (analysis) | Client management drew "only the Back End talks to storage" and suggested NFS (2049) or SFTP (22). Our analysis, recommending to keep S3 on `9000` (already open) and build the relay: [`STORAGE-PROTOCOL-OPTIONS.md`](../minio/STORAGE-PROTOCOL-OPTIONS.md). Until it is released testers can upload but not view files. Open question for management. |

## To do, in order (added 2026-10-27, so nothing is forgotten)

The backend is deployed and reachable from the frontend server. Testing on production uses **dummy data only**. The list
has two parts: what happens during testing, and what must be finished **before real data** goes in.

### Now, during testing

- [ ] Give `admin@dofi.gov.bn` its real Active Directory name. Staff have no DoFi password (the default `ChangeMe123!` hash is cleared by migration `BlankStaffEncryptedPasswords` on the first deploy of the AD change), so there is no password to change:

  ```bash
  cd /opt/dofi
  docker compose exec api bin/rails admin:assign_ad_username EMAIL=admin@dofi.gov.bn AD_USERNAME=mprt/<real ad name>
  ```

- [ ] Frontend team: call the API at `http://10.252.8.12:3000`; one JWT-authenticated loader for Dictionary images (no bare `<img src>`); their nginx proxies `/api` and `/cable` with bodies of at least 12 MB. Brief: [`FE-DISCUSSION-FILE-DELIVERY.md`](../minio/FE-DISCUSSION-FILE-DELIVERY.md).
- [ ] Human end-to-end test from the frontend: log in, upload a vessel image and a PDF, open both again. This is the first real proof of upload and the file relay against the real MinIO (tests used the disk service); in the browser's Network tab no request may go to `10.252.8.13`. Record the result in [`UPLOAD-REGRESSION-2026-10-27.md`](../minio/UPLOAD-REGRESSION-2026-10-27.md).

### After testing, before real data (nothing here blocks testing)

| # | Item | Done when |
|---|---|---|
| 1 | **Backups.** Install the nightly `pg_dump` on the database server ([section G](#g-backups-minimum)) and copy it off the host. | A dump exists, is copied off-host, and one restore into a scratch database has been tested. |
| 2 | **ROCBN account.** Ask the MySQL owner to limit `stuser` to `SELECT` on `tdd_db.sync_rocbn_hotel`, ideally only from `10.252.8.12` (today: `ALL PRIVILEGES` from any host, flagged by `rocbn:check`). | `bin/rails rocbn:check` on the backend no longer prints the `ALL PRIVILEGES` warning and the lookup still works. |
| 3 | **Reset the demo data.** Reset the databases and seed reference data only. The demo seeds no longer run on production (`db/seeds.rb`, using `DEPLOY_ENV`), so set `ADMIN_AD_USERNAME` (the superadmin's real AD name) in `.env` before the first `db:prepare` instead of a password. Only the databases on this server, only with explicit confirmation. | No `ChangeMe123!` account exists, no demo manifests or companies remain, reference data is back. |
| 4 | **BruneiID.** Get the host and credentials from the client, fill `BRUNEIID_*` in `/opt/dofi/.env`, register the redirect URI (it must match character for character: see the [post-mortem](../incidents/POSTMORTEM-2026-10-02-brunei-id-redirect-uri-mismatch.md)), and ask for outbound `443` to that host. | A Brunei ID login completes from the frontend. |
| 5 | **Domain and TLS.** HTTPS on the backend's nginx ([runbook, step 10](../../deploy/production/backend/README.md#10-later-a-domain-and-tls)), `FORCE_SSL=true`, `https://` origins in `CORS_ORIGINS` and `CABLE_ALLOWED_ORIGINS`, and `wss://` for the WebSocket. Tell the frontend team. | The frontend works over HTTPS with no mixed-content errors. |

Also open, lower priority: Sentry events need outbound `443` to `*.ingest.us.sentry.io` (works today; add it to the client's whitelist so it survives a firewall review), and the rest of [section I](#i-not-done-yet).

## A. Get from the client

- [ ] **The firewall rules, requested first.** Every later step needs them: `db:prepare` needs the database port, the Add Profiling company lookup needs the registry's MySQL port (row 12), the first boot needs MinIO, `docker pull` needs outbound access to `ghcr.io`. The table to send is [§3 of the architecture doc](../architecture/production-4-server-architecture.md#3-network-firewall-request); the client's change takes days, so ask before anything is deployed, not after. To prove each row is open, run [the connectivity check](NETWORK-CONNECTIVITY-CHECK.md).
- [ ] The four server IPs (private and, if different, the one browsers use). The database host is `OGCMPT003API001` (the client's name, per their screenshot).
- [ ] Working `sudo` on the database host (`localadmin`), and approval to install the `postgresql-16` package there. It already runs MySQL 8.0 for another system; ours is a separate package and port. Port 9139 is that MySQL, which also holds the ROCBN company registry we read (next item).
- [ ] **A MySQL account for the ROCBN registry** (status 2026-10-27: account `stuser` received and in the backend `.env`; port 9139 from the backend is still `Connection refused`, firewall row 12 to be followed up with the client; `SELECT`-only is not proven until `rocbn:check` runs) (the client's DBA creates it): `SELECT` on `tdd_db.sync_rocbn_hotel` only, allowed from the backend server's address (`10.252.8.12`). Ask which authentication plugin it uses; `caching_sha2_password` and `mysql_native_password` both work. Its username and password go into the backend `.env` (C3). The lookup is read-only by design, so an account that can do more should be refused: `rocbn:check` (section D) warns about it.
- [ ] Which networks (users' LAN/VPN) may reach the frontend `4100`, backend `80` (nginx; port 3000 stays internal) and storage `9000`; database `5432` only from the backend server.
- [ ] The outbound whitelist confirmed in writing, from the App Server on TCP 443: BruneiID host (`BRUNEIID_BASE_URL`), `ghcr.io`, `pkg-containers.githubusercontent.com`. For the fallback build (section J) also `ssh.github.com`, `github.com`, Docker Hub, Debian mirrors (80 and 443) and RubyGems; the exact list is in [the architecture doc, §3](../architecture/production-4-server-architecture.md#3-network-firewall-request). The storage server needs `ghcr.io` too, and the database server needs the Ubuntu apt mirrors.
- [ ] How we log in to the servers: Delinea SSH terminal over VPN. No inbound access from GitHub is needed or requested.
- [ ] The frontend's origin exactly as browsers use it, scheme and port included (for example `http://10.246.8.12:4100`): it goes into `CORS_ORIGINS` and `CABLE_ALLOWED_ORIGINS`. The architecture doc still has an open question on whether its IP is `.11` or `.12`.

## B. GitHub

Nothing on GitHub has to reach the servers, so there are no SSH keys or `PRODUCTION_SSH_*` secrets to create.

- [ ] The workflow "CD Production" is green on `main` once: `Test & Security`, then `Build & Push GHCR`. Check that `ghcr.io/arya020595/st_dofi_backend` has the tags `production` and the commit SHA (repo, Packages).
- [ ] `SLACK_WEBHOOK_URL` (optional): Slack then posts "image pushed, manual deployment required" after each build.
- [ ] A read-only token the servers use to pull the **private** images: GitHub, Settings, Developer settings, Personal access tokens (classic), scope `read:packages` only. Nothing renews it, so **write down its expiry date**: when it expires every `docker compose pull` fails with `unauthorized`. It is used for `docker login` on the backend server (C3) and the storage server (C2).
- [ ] Only if the client ever allows GitHub to SSH in: follow the steps in the comment above the `deploy` job in `cd-production.yml` (SSH key, `PRODUCTION_SSH_*` secrets, `production` environment reviewers, remove `if: ${{ false }}`). Not part of this checklist.

## C. Servers, in this order: database, storage, backend

Do each step on the server named. All commands run in the server's SSH or Delinea terminal.

### C1. Database server (`OGCMPT003API001`, native PostgreSQL 16, no Docker)

Replace `<DB_IP>` with 10.252.8.23 and `<BACKEND_IP>` with 10.252.8.12. Details: [database runbook](../../deploy/production/database/README.md).

- [ ] Look first (read-only). Ubuntu 24.04 expected; port 5432 must be free.

  ```bash
  lsb_release -a; free -h; nproc; df -h
  systemctl is-active ufw
  sudo ss -lntp | grep -E ':(5432|9139)\b'                  # 5432 must be absent; 9139 is the existing MySQL (the ROCBN registry, not ours)
  ```

- [x] Install PostgreSQL 16 (a separate package and port from the MySQL already on the host):

  ```bash
  sudo apt update && sudo apt install -y postgresql-16
  ```

- [x] Configure the drop-in file (the packaged `postgresql.conf` stays untouched) and allow only the backend server. Size `shared_buffers` at about 25% of the RAM MySQL leaves free (`free -h`); 1GB is a placeholder.

  First keep a copy of the original rules file and check the IP belongs to this host (stop if the second command prints nothing):

  ```bash
  sudo cp -a /etc/postgresql/16/main/pg_hba.conf /etc/postgresql/16/main/pg_hba.conf.orig
  ip -4 addr | grep <DB_IP>
  ```

  Then, once only (the `echo` appends, so a second run duplicates the rule):

  ```bash
  sudo tee /etc/postgresql/16/main/conf.d/dofi.conf <<'EOF'
  listen_addresses = 'localhost,<DB_IP>'
  max_connections = 100
  shared_buffers = 1GB
  password_encryption = scram-sha-256
  log_min_duration_statement = 1000
  EOF
  echo 'host  all  dofi  <BACKEND_IP>/32  scram-sha-256' | sudo tee -a /etc/postgresql/16/main/pg_hba.conf
  ```

  Replace `<DB_IP>` and `<BACKEND_IP>` with the real addresses before running. A terminal can mangle a pasted multi-line block, so read back what was written before restarting:

  ```bash
  cat /etc/postgresql/16/main/conf.d/dofi.conf     # exactly the five lines above
  sudo tail -n 2 /etc/postgresql/16/main/pg_hba.conf    # root and postgres only can read it; the last line is the dofi rule
  ```

- [x] Create the `dofi` role (`LOGIN CREATEDB`, not superuser). Type the password interactively so it stays out of shell history, and **save it** for the backend `.env` (`DATABASE_PASSWORD`).

  ```bash
  sudo -u postgres psql
  postgres=# CREATE ROLE dofi LOGIN CREATEDB;
  postgres=# \password dofi
  postgres=# \q
  ```

- [x] Open the host firewall only if `ufw` is active (SSH first), then restart PostgreSQL (`listen_addresses` needs a restart; MySQL is not affected):

  ```bash
  sudo ufw status
  sudo ufw allow from <BACKEND_IP> to any port 5432 proto tcp     # only if ufw is active
  sudo systemctl restart postgresql
  ```

  If PostgreSQL does not start, or you need to back out any of these changes, see [Undo and troubleshooting](../../deploy/production/database/README.md#undo-and-troubleshooting).

- [ ] Check:

  ```bash
  sudo ss -lntp | grep 5432                                  # listening on <DB_IP> and 127.0.0.1
  sudo -u postgres psql -c 'SHOW listen_addresses;'
  # later, from the BACKEND server:
  nc -vz <DB_IP> 5432                                        # succeeded
  psql -h <DB_IP> -U dofi -d postgres -c 'select 1'          # needs the postgresql-client package; wrong password must be rejected
  ```

  The four databases (`dofi_backend_production` and its `_cache`, `_queue`, `_cable`) are created by the backend's first `db:prepare`; create nothing by hand.

- [ ] Add a nightly backup (section G).

### C2. Storage server (`OGCMET001API002`, MinIO in Docker)

Replace `<GITHUB_USER>` with the GitHub account that owns the read-only token. Details: [`deploy/README.md`](../../deploy/README.md).

- [x] Install Docker Engine and the Compose plugin, put the deploy user in the `docker` group, and create `/opt/dofi` (done on `OGCMET001API002` from Docker's official apt repository, `download.docker.com`, which that host can reach; the Ubuntu packages below also work):

  ```bash
  docker --version; docker compose version                  # skip the install if both already print a version
  sudo apt update && apt-cache policy docker.io docker-compose-v2     # both need a Candidate (Ubuntu 24.04 universe)
  sudo apt install -y docker.io docker-compose-v2            # Ubuntu's own packages: no extra apt repository to whitelist
  sudo usermod -aG docker "$USER"                            # log out and back in afterwards
  docker --version; docker compose version; docker info > /dev/null && echo docker-ok
  sudo mkdir -p /opt/dofi && sudo chown "$USER": /opt/dofi
  ```

- [x] Log in to the registry (the MinIO image is a private mirror). `read -s` keeps the token out of the history:

  ```bash
  read -rs GHCR_TOKEN && echo "$GHCR_TOKEN" | docker login ghcr.io -u <GITHUB_USER> --password-stdin; unset GHCR_TOKEN
  ```

- [x] Copy three files from the repo to `/opt/dofi` (from a machine with the repo; through Delinea, paste each into `nano` instead):

  ```bash
  scp deploy/production/storage/docker-compose.yml deploy/production/storage/.env.example docker/mc-init.sh <user>@<STORAGE_IP>:/opt/dofi/
  ```

- [x] Create and fill `.env`. **Save the bucket names and the two access key pairs** for the backend `.env`.

  ```bash
  cd /opt/dofi && cp .env.example .env && chmod 600 .env
  openssl rand -hex 32          # run once per secret: MINIO_ROOT_PASSWORD, MINIO_SECRET_ACCESS_KEY, MINIO_ASSETS_SECRET_ACCESS_KEY
  nano .env                     # MINIO_ROOT_USER, MINIO_ROOT_PASSWORD, MINIO_ACCESS_KEY_ID, MINIO_SECRET_ACCESS_KEY,
                                # MINIO_ASSETS_ACCESS_KEY_ID, MINIO_ASSETS_SECRET_ACCESS_KEY (bucket names keep their defaults)
  ```

- [x] Start MinIO and create the buckets and the app's access keys (`mc-init` is safe to re-run):

  ```bash
  cd /opt/dofi
  docker compose up -d --wait && docker compose run --rm mc-init
  ```

- [ ] Check:

  ```bash
  docker compose ps                                          # minio: Up (healthy)
  curl -i http://<STORAGE_IP>:9000/minio/health/live         # 200
  ```

### C3. Backend server (`OGCMET001API001`): prepare

Docker and nginx are installed. Full explanations: [backend runbook](../../deploy/production/backend/README.md) (step numbers in brackets).

- [x] Look first, read-only (step 0). A failure here is a firewall or server-order problem, not something to fix on this server. (2026-10-27: DB 5432, MinIO 9000 and ghcr.io all `OPEN`; Docker 29.9.2, Compose v5.6.0, nginx 1.24; `:80` is nginx, `:3000` free. Only `default` is in `sites-enabled`. Registry `9139` not checked yet.)

  ```bash
  lsb_release -a; free -h; nproc; df -h
  docker --version; docker compose version
  nginx -v; systemctl is-active nginx ufw
  ls /etc/nginx/sites-enabled                                # only `default` expected; any other site is not ours: leave it
  sudo ss -lntp | grep -E ':(80|3000)\b'                     # 80 = nginx; 3000 must be free
  nc -vz <DB_IP> 5432; nc -vz <STORAGE_IP> 9000              # needs C1 and C2 done and firewall rows 4 and 5; fuller version: NETWORK-CONNECTIVITY-CHECK.md
  curl -sI https://ghcr.io | head -1                         # firewall row 7
  ```

- [x] The deploy user (`localadmin`) is in the `docker` group and owns `/opt/dofi` (step 1; CD runs `docker` without `sudo`); done 2026-10-27:

  ```bash
  sudo usermod -aG docker "$USER"                            # log out and back in afterwards
  docker info > /dev/null && echo docker-ok
  sudo mkdir -p /opt/dofi/nginx && sudo chown -R "$USER": /opt/dofi
  ```

- [x] Log in to the registry with the read-only token from B (done 2026-10-27, `Login Succeeded` as `arya020595`; the token is stored unencrypted in `~/.docker/config.json`, so keep that file `600`). Every release pulls with this login; if a later `pull` says `unauthorized`, the token expired: repeat this (step 2):

  ```bash
  read -rs GHCR_TOKEN && echo "$GHCR_TOKEN" | docker login ghcr.io -u <GITHUB_USER> --password-stdin; unset GHCR_TOKEN
  ```

- [x] Copy the three files to `/opt/dofi` (step 3; done 2026-10-27 through Delinea). Where `scp` may not work, paste each file into `nano` instead, or send it as one line of base64 (a multi-line paste can be mangled by the terminal) and compare the checksum afterwards:

  ```bash
  # from a machine with the repo
  scp deploy/production/backend/docker-compose.yml deploy/production/backend/.env.example <user>@<BACKEND_IP>:/opt/dofi/
  scp deploy/production/backend/nginx/dofi-api.conf <user>@<BACKEND_IP>:/opt/dofi/nginx/

  # Delinea alternative. On the machine with the repo, print one line per file:
  for f in docker-compose.yml .env.example nginx/dofi-api.conf; do
    echo "echo '$(base64 -w0 deploy/production/backend/$f)' | base64 -d > /opt/dofi/$f"
  done
  sha256sum deploy/production/backend/{docker-compose.yml,.env.example,nginx/dofi-api.conf} | cut -c1-12,65-
  # Paste each printed line on the server, then run the same sha256sum there (cd /opt/dofi) and compare the first 12 characters.
  ```

- [x] Create `/opt/dofi/.env` and fill it in (step 3; done 2026-10-27 with `BRUNEIID_*` and `SENTRY_DSN` still empty, the client has not supplied them; `ROCBN_DB_USERNAME=stuser`). Fill the secrets without echoing them: a small `setenv KEY` function that does `read -rs` and rewrites that one line of `.env`, so nothing lands in the shell history or in a chat:

  ```bash
  cd /opt/dofi && cp .env.example .env && chmod 600 .env
  openssl rand -hex 32          # DEVISE_JWT_SECRET_KEY (changing it later signs every user out)
  nano .env
  ```

  | Variable | Value |
  |---|---|
  | `RAILS_MASTER_KEY` | content of `config/master.key` from the repo owner's checkout; without it the app does not boot |
  | `DEVISE_JWT_SECRET_KEY` | the `openssl rand -hex 32` output |
  | `FORCE_SSL` | `false` (no certificate yet) |
  | `DATABASE_HOST`, `DATABASE_PASSWORD` | `<DB_IP>` and the `dofi` role's password from C1; `DATABASE_USERNAME` stays `dofi` |
  | `CORS_ORIGINS`, `CABLE_ALLOWED_ORIGINS` | `<FE_ORIGIN>` in both: scheme, host and port exactly as the browser shows it, no trailing slash |
  | `MINIO_ENDPOINT`, `MINIO_PUBLIC_ENDPOINT` | both `http://<STORAGE_IP>:9000` |
  | `MINIO_BUCKET`, `MINIO_ASSETS_BUCKET` and the four access/secret keys | copied from the storage server's `.env` (C2) |
  | `ROCBN_DB_HOST`, `ROCBN_DB_PORT`, `ROCBN_DB_NAME` | `10.252.8.23`, `9139`, `tdd_db` (already in `.env.example`) |
  | `ROCBN_DB_USERNAME`, `ROCBN_DB_PASSWORD` | the registry account from section A. Never set `ROCBN_SEED_*`, `ROCBN_TEST_*` or `ROCBN_ALLOW_SEED` here: production is never seeded |
  | `BRUNEIID_*` | from the client; `BRUNEIID_REDIRECT_URI` must match the URI registered at BruneiID character for character |

- [x] Validate it (2026-10-27: `env-ok`, mode `600`, master key 32 characters, JWT secret 64, no CR, no trailing space or quotes). `-q` prints nothing on success; plain `docker compose config` would print the secrets. To list which keys are filled without showing values: `awk -F= '/^[A-Z_]+=/ {print $1, ($2=="" ? "EMPTY" : "set")}' .env`. The MinIO key pairs must be copied from the storage server's `.env`, never regenerated: `mc-init` registered exactly those pairs in MinIO:

  ```bash
  cd /opt/dofi && docker compose config -q && echo env-ok
  ```

## D. First run by hand, with nginx in front (required once)

This is the first release, and it also sets up nginx and the firewall, which releases never touch. C1 and C2 must be running first: `db:prepare` creates the four databases and seeds reference data including images.

- [ ] Start the stack (backend runbook step 4):

  ```bash
  cd /opt/dofi
  docker compose pull
  docker compose run --rm api bin/rails db:prepare           # creates the 4 databases, seeds reference data
  docker compose up -d
  docker compose ps                                          # api and jobs: Up
  docker compose logs --tail 50 api jobs                     # no stack traces
  curl -i http://127.0.0.1:3000/up                           # 200 (works only from this host)
  ```

  If `pull` says the `:production` tag is not found, the image was never built: merge to `main` and wait for the green `Build & Push GHCR` job (section B).

  **Status 2026-10-27:** `pull` and `db:prepare` done on the backend server. The four databases were created, the migrations and seeds ran, and 17 files were uploaded to MinIO, which proves backend to database and backend to MinIO. `up -d`, `ps`, logs and `/up` are still to do.

  > **Historical note (2026-10-27): the first `db:prepare` ran the whole `db/seeds.rb`, which then included demo records** (16 company profiles, 21 vessels, 23 crew, 24 fisherman users, 1 jetty manager, the Brunei ID sandbox users, 11 manifests) with the default password `ChangeMe123!`. **This server still has them.** `db/seeds.rb` now skips the demo seeds when `DEPLOY_ENV=production`, so a new or reset database gets reference data only, but nothing removes the existing rows: delete them (or reset the databases) as part of the AD cut-over in `docs/registration/active-directory-login.md`, before real users are told the system is live.

- [ ] The ROCBN registry answers (needs firewall row 12 and the account from section A). Read-only: it prints the account's privileges and warns if it holds more than `SELECT`:

  ```bash
  cd /opt/dofi
  docker compose run --rm --no-deps api bin/rails rocbn:check       # exit 0, "privileges  SELECT only"
  ```

  Nothing else depends on it: if the registry is down the API keeps serving, and only the company lookup answers `503`.

- [ ] nginx in front of the API (step 5):

  ```bash
  sudo cp /opt/dofi/nginx/dofi-api.conf /etc/nginx/sites-available/dofi-api
  sudo ln -sf /etc/nginx/sites-available/dofi-api /etc/nginx/sites-enabled/dofi-api
  sudo nginx -t && sudo systemctl reload nginx               # never skip the -t
  curl -i http://10.252.8.12:3000/up                         # 200 (this is nginx; 127.0.0.1:3000 is Rails itself)
  ```

- [x] Host firewall (step 6). This host runs `firewalld`, which rejects everything not listed. Allow only the frontend to 3000, without `--reload`:

  ```bash
  RULE='rule family="ipv4" source address="10.246.8.12" port port="3000" protocol="tcp" accept'
  sudo firewall-cmd --add-rich-rule="$RULE"
  sudo firewall-cmd --permanent --add-rich-rule="$RULE"
  ```

- [ ] From the frontend server (or any machine on the users' network), prove what a browser will meet (step 7):

  ```bash
  curl -i http://<BACKEND_IP>/up                             # 200

  # CORS preflight: expect 200 and `access-control-allow-origin: <FE_ORIGIN>`
  curl -i -X OPTIONS http://<BACKEND_IP>/api/v1/auth/sign_in \
    -H 'Origin: <FE_ORIGIN>' -H 'Access-Control-Request-Method: POST' \
    -H 'Access-Control-Request-Headers: content-type,authorization'

  # WebSocket handshake: expect `HTTP/1.1 101 Switching Protocols` (curl stops after 5 s; 404 = CABLE_ALLOWED_ORIGINS wrong)
  curl -i -N --max-time 5 http://<BACKEND_IP>/cable \
    -H 'Connection: Upgrade' -H 'Upgrade: websocket' -H 'Sec-WebSocket-Version: 13' \
    -H 'Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==' -H 'Origin: <FE_ORIGIN>'
  ```

## E. Release by hand (every update after the first run)

CI has already built the image; the server only pulls it. Run this in the Delinea terminal on the backend server.

- [ ] Merge to `main`, then wait until the workflow "CD Production" shows `Build & Push GHCR` green (Slack says "Manual deployment required").
- [ ] If the compose file changed in this release, paste the new `deploy/production/backend/docker-compose.yml` into `/opt/dofi/docker-compose.yml` first (nothing copies it for you), then `docker compose config -q`.
- [ ] Release:

  ```bash
  cd /opt/dofi
  docker compose pull
  docker compose run --rm api bin/rails db:prepare
  docker compose up -d --wait
  curl -fsS http://127.0.0.1:3000/up
  docker compose ps
  docker image prune -f
  ```

- [ ] Check the logs for 2 minutes: `docker compose logs --since 2m api jobs`.
- [ ] To run a specific build instead of the newest, set `IMAGE_TAG=<git sha>` in `/opt/dofi/.env` before `pull` (the same is how you roll back, section H).

## F. Verify the whole system

- [ ] Log in from the frontend (BruneiID or the admin account).
- [ ] The seeded admin `admin@dofi.gov.bn` exists: **change its password immediately**.
- [ ] Upload a file (a company document or vessel image), then open it; the browser must be able to reach `http://<STORAGE_IP>:9000`.
- [ ] No CORS error in the browser console; a WebSocket (notifications) connects.
- [ ] Logs are clean (on the backend server):

  ```bash
  cd /opt/dofi && docker compose logs --tail 100 api jobs
  sudo tail -n 50 /var/log/nginx/error.log
  ```

- [ ] Give the frontend team the API URL `http://<BACKEND_IP>:3000` and the WebSocket URL `ws://<BACKEND_IP>:3000/cable`.

## G. Backups (minimum)

On the database server, replacing nothing (the database name is `dofi_backend_production`). Details: [database runbook, step 6](../../deploy/production/database/README.md#6-backups-minimum-before-go-live).

- [ ] Install the nightly `pg_dump` cron job (14-day retention in `/var/backups/dofi`):

  ```bash
  sudo install -d -o postgres -g postgres -m 700 /var/backups/dofi
  sudo tee /usr/local/bin/dofi-backup <<'EOF'
  #!/bin/sh
  set -eu
  dir=/var/backups/dofi
  pg_dump -Fc dofi_backend_production > "$dir/primary-$(date +%F).dump"
  find "$dir" -name 'primary-*.dump' -mtime +14 -delete
  EOF
  sudo chmod 755 /usr/local/bin/dofi-backup
  echo '0 2 * * * postgres /usr/local/bin/dofi-backup' | sudo tee /etc/cron.d/dofi-backup
  sudo -u postgres /usr/local/bin/dofi-backup && ls -l /var/backups/dofi     # run it once now to prove it works
  ```

- [ ] Copy the dumps to a place the client controls.
- [ ] Do one restore into a scratch database before go-live:

  ```bash
  sudo -u postgres createdb dofi_restore_test
  sudo -u postgres pg_restore -d dofi_restore_test --clean --if-exists /var/backups/dofi/primary-<date>.dump
  sudo -u postgres dropdb dofi_restore_test
  ```

## H. Operate, rollback and troubleshooting

On the backend server:

```bash
cd /opt/dofi
docker compose logs -f --tail 100 api jobs                   # app logs
docker compose up -d                                         # after editing .env: recreates only what changed
sudo nginx -t && sudo systemctl reload nginx                 # after editing the vhost
```

**Roll back the backend:** edit `/opt/dofi/.env`, set `IMAGE_TAG=<previous git sha>`, run `docker compose up -d`. Database migrations are **not** rolled back, so keep migrations compatible with the previous release.

| Symptom | Likely cause and fix |
|---|---|
| `docker compose pull` says `unauthorized` | The `read:packages` token from B expired or was revoked: make a new one and repeat the `docker login` (C3). |
| `docker compose pull` says the tag is not found | CI did not push it: check the `Build & Push GHCR` job on the commit, or use section J. |
| `docker compose` says `.env` is missing | Create `/opt/dofi/.env` on the backend server (C3). |
| `502 Bad Gateway` from the backend's nginx | `api` is down or still booting: `docker compose ps` and `logs api`, then `curl http://127.0.0.1:3000/up` on the server. More in [the backend runbook](../../deploy/production/backend/README.md#9-troubleshooting). |
| `db:prepare` cannot connect | Wrong `DATABASE_HOST`/`DATABASE_PORT`/password, or the client's firewall blocks `5432` from the backend. |
| The company lookup answers `503`, or `rocbn:check` fails | Run `docker compose run --rm --no-deps api bin/rails rocbn:check`. Connection refused or a timeout: firewall row 12, or a wrong `ROCBN_DB_HOST`/`ROCBN_DB_PORT`. `Access denied`: wrong account or password, or the account is not allowed from `10.252.8.12`. An authentication plugin error: ask the DBA which plugin the account uses. `lacks: <column>`: the registry's table changed; tell the backend team. [More](../rocbn/company-lookup.md#troubleshooting). |
| `db:prepare` fails while seeding images | MinIO not running, or the keys in the backend `.env` do not match the storage `.env`; run C2 and `mc-init` first. |
| Browser CORS error | Frontend origin missing in `CORS_ORIGINS` / `CABLE_ALLOWED_ORIGINS`; edit `.env`, `docker compose up -d`. |
| File links `403 SignatureDoesNotMatch` | `MINIO_PUBLIC_ENDPOINT` differs from the address the browser actually uses. |
| Login loops or redirects to HTTPS | `FORCE_SSL` must be `false` while there is no certificate. |

## I. Not done yet

- A domain and certificates: HTTPS on the backend's nginx ([runbook, step 10](../../deploy/production/backend/README.md#10-later-a-domain-and-tls)), a proxy in front of MinIO, then `FORCE_SSL=true`.
- A second `api` replica for zero-downtime releases; TLS between servers.
- Off-host backups with a schedule and a tested restore.
- Remove the old root `docker-compose.production.yml` once the old production server is retired (staging and local still use `docker/mc-init.sh`).

## J. Fallback: build on the server (only if CI or ghcr.io is down)

For an urgent fix when no image can be pulled. Needs the fallback part of the whitelist (section A). Full explanation:
[backend runbook, section 11](../../deploy/production/backend/README.md#11-fallback-build-on-the-server-approach-b).

- [ ] One time, as the deploy user on the backend server: a read-only GitHub **deploy key** and an SSH config that reaches GitHub on port 443, then clone the repo (replace nothing; the key is added in the repo's Settings, Deploy keys, without write access):

  ```bash
  ssh-keygen -t ed25519 -f ~/.ssh/dofi_github_readonly -N ""
  cat ~/.ssh/dofi_github_readonly.pub          # add this line as a Deploy key in the GitHub repo
  nano ~/.ssh/config                           # paste the Host block below, then: chmod 600 ~/.ssh/config
  ssh -T git@github.com                        # "successfully authenticated"
  git clone git@github.com:arya020595/st_dofi_backend.git /opt/dofi/src
  cp /opt/dofi/src/deploy/production/backend/docker-compose.build.yml /opt/dofi/
  ```

  ```
  Host github.com
    HostName ssh.github.com
    Port 443
    User git
    IdentityFile ~/.ssh/dofi_github_readonly
    IdentitiesOnly yes
  ```

- [ ] Each fallback release (both `-f` files every time, or Compose returns to the GHCR image):

  ```bash
  cd /opt/dofi/src && git pull --ff-only && git log -1 --oneline
  cd /opt/dofi
  docker compose -f docker-compose.yml -f docker-compose.build.yml build
  docker compose -f docker-compose.yml -f docker-compose.build.yml run --rm api bin/rails db:prepare
  docker compose -f docker-compose.yml -f docker-compose.build.yml up -d --wait
  curl -fsS http://127.0.0.1:3000/up
  ```

- [ ] Back to normal releases once CI works again: `docker compose pull && docker compose up -d` (without the override).
