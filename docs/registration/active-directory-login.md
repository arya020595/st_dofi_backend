# Active Directory sign-in for DoFi staff

DoFi Officers and every other internal DoFi role ("staff") sign in to `POST /api/v1/auth/sign_in` with their Active
Directory (AD) username and AD password. The backend checks the password and then issues the same JWT as before.
There is no local DoFi password for staff in any environment. This page is the design and the operations guide.
The questions still open with the client are in
[active-directory-integration-requirements.md](active-directory-integration-requirements.md).

New to this code? Start with the learning guide in [`docs/active-directory/`](../active-directory/README.md)
(business context, architecture and sequence diagrams, a code walkthrough, and troubleshooting).

Fishermen and Jetty Managers are not affected: they keep signing in through BruneiID (and their existing sign-in).

## What AD decides and what DoFi decides

| The directory (AD, or the mock) | DoFi (PostgreSQL) |
|---|---|
| Is this password right for this account? | Does a DoFi user exist for this username? |
| | Is it `active` and not discarded? |
| | What role and permissions does it have? |

No user and no role is ever created from AD. An AD account with no matching DoFi user cannot sign in, and a DoFi user
whose password the directory rejects cannot sign in. The Add User form has no password field, the API ignores a
`password` param and returns no `temporary_password`.

"Staff" means any user whose role is on the DoFi Officer platform and is not a Jetty Manager
(`Role.directory_managed` / `User.directory_managed`). That includes custom DoFi roles.

## Environments

| Where | `DEPLOY_ENV` | `AD_MODE` | Passwords |
|---|---|---|---|
| Local development and tests | unset (it is `RAILS_ENV`) | `mock` (default when unset) | every staff user shares `AD_MOCK_PASSWORD` |
| Staging | `staging` | `mock` (or `ldap` to test the real AD) | every staff user shares `AD_MOCK_PASSWORD` |
| Production | `production` | **`ldap`** | each person's own AD password |

Staging runs with `RAILS_ENV=production` too, so `RAILS_ENV` cannot tell the two apart. `DEPLOY_ENV` does, and it is
set by each deployment's **compose file** (`docker-compose.staging.yml`, `deploy/production/backend/docker-compose.yml`,
`docker-compose.production.yml`), not by the server `.env`. The app **refuses to boot** (`Authentication::DirectoryConfig`)
when:

- `RAILS_ENV=production` and `DEPLOY_ENV` is not `staging` or `production`
- `AD_MODE` is not `mock` or `ldap` (there is no "disabled" mode), or is unset under `RAILS_ENV=production`
- **`AD_MODE=mock` and `DEPLOY_ENV=production`**, with or without a mock password

`test/config/deployment_environment_test.rb` pins `DEPLOY_ENV` in each compose file and `AD_MODE=ldap` in the production
env example, so an edit that weakens this fails the suite.

### The mock directory (local and staging)

Every staff user keeps their own username (`mprt/azri.nizam`, ...) and all of them share **one** password, `AD_MOCK_PASSWORD`,
set once per environment in that environment's `.env`. It is never committed (the examples leave it empty), never stored
as a user's password, and only compared in constant time against what was typed. A username still has to belong to an
existing, `active`, non-discarded staff user, so unknown, inactive, suspended and discarded users are refused even with
the right mock password. Typing `simulate-ad-unavailable` as the password simulates a directory outage (HTTP 503) so the
frontend can test that path. A blank `AD_MOCK_PASSWORD` never signs anyone in: it answers 503 and logs why.

The mock logs a warning at boot on staging. Anyone who knows `AD_MOCK_PASSWORD` can sign in as any staff user in that
environment, so keep staging's value out of the repository and out of chat.

## Configuration

All read in one place, `Authentication::DirectoryConfig`.

| Variable | Default | Meaning |
|---|---|---|
| `AD_MODE` | `mock` outside production, required in production | `mock` or `ldap` |
| `AD_MOCK_PASSWORD` | none | The shared mock password (mock mode only) |
| `AD_HOST` | none | Comma-separated DNS names, tried in order. They must be covered by the server certificate. **IP addresses are rejected.** |
| `AD_PORT` | `3269` | LDAPS port. Port 389 (plaintext) is rejected. 3269 is the Global Catalog over TLS; 636 is plain LDAPS. Use the one the AD team confirms. |
| `AD_NETBIOS_DOMAIN` | `MPRT` in mock mode, required for ldap | e.g. `MPRT`. Used for the bind name and to recognise `MPRT/` and `MPRT\` in what people type. |
| `AD_DNS_DOMAIN` | none | e.g. `MPRT.EG.GOV.BN`. Only used by the `upn` bind format. |
| `AD_BIND_FORMAT` | `netbios` | `netbios` binds as `MPRT\name`, `upn` as `name@MPRT.EG.GOV.BN`. **Not yet confirmed against the real AD.** |
| `AD_CA_FILE` | none: the container's system trust store | **Optional.** PEM file with the CA certificate(s) to trust instead of the system store, as a path inside the container. See "The CA certificate". |
| `AD_CONNECT_TIMEOUT` | `3` | Seconds to connect and complete TLS, per host |
| `AD_OPERATION_TIMEOUT` | `5` | Seconds to wait for the bind answer |
| `ADMIN_AD_USERNAME` | mock default outside production, **required in production** | The superadmin's AD username, used only by `db:seed` on a fresh database |

A real-directory configuration that cannot work (missing host, IP address, port 389, unreadable CA file, ...) does not
break boot: it makes staff sign-in return **503** and logs the reasons (`ad.directory_unavailable`). It never falls back
to anything else.

### The CA certificate

Certificate verification is **always on**: the server's certificate chain must be trusted, it must be valid today, and
its name must match the `AD_HOST` entry that was dialled (TLS 1.2 or newer). Nothing in the application can switch this
off, and a test fails if code that does so is added. A failed check is the same 503 as any directory outage.

`AD_CA_FILE` only decides **who is trusted**:

| `AD_CA_FILE` | Trusted CAs | Notes |
|---|---|---|
| unset or blank (default) | The container's system trust store (`ca-certificates`, already in the image) | Enough when the AD certificate chains to a CA in that store. |
| a path | **Only** the CAs in that file | Replaces the system store, it does not add to it. The file must be PEM with at least one certificate. If it is missing, unreadable or not a certificate, sign-in answers 503 and the system store is **not** used instead. |

AIMS and TIMS needing no separate CA file does not prove the AD certificate chains to a CA in the system store: those
systems may never have verified the certificate. Whether DoFi needs a file is answered by the TLS check below.

If the AD certificate is issued by an internal CA, the AD team supplies that Root CA and any intermediate CA as public
PEM (never a private key). Put them in one file on the host, mount it read-only into the `api` container (see the
commented `volumes:` example in `deploy/production/backend/docker-compose.yml`) and set `AD_CA_FILE` to the container
path. Do not add certificates to the repository, download them automatically, or change the image's system store.

## Verifying LDAPS from the backend container

Run these **inside the `api` container** on the server (`docker compose exec api bash`). Do not assume the AD servers
are reachable from a laptop. The values below are the **candidate** FQDNs and port, not confirmed facts.

```bash
# A. DNS
getent hosts prtauthpro1.mprt.eg.gov.bn

# B. TCP (the image has no nc; use nc -vz -w 5 HOST 3269 if you have it)
timeout 5 bash -c '</dev/tcp/prtauthpro1.mprt.eg.gov.bn/3269' && echo "port open"

# C. TLS with the system trust store, checking the chain and the host name
openssl s_client -connect prtauthpro1.mprt.eg.gov.bn:3269 -servername prtauthpro1.mprt.eg.gov.bn \
  -verify_hostname prtauthpro1.mprt.eg.gov.bn -verify_return_error -brief </dev/null

# C'. The same with a CA file the AD team supplied (what AD_CA_FILE would use)
openssl s_client -connect prtauthpro1.mprt.eg.gov.bn:3269 -servername prtauthpro1.mprt.eg.gov.bn \
  -verify_hostname prtauthpro1.mprt.eg.gov.bn -verify_return_error -CAfile /etc/dofi/ad-ca.pem -brief </dev/null

# D. The application's own bind, once, with a dedicated AD test account (the password is not echoed or stored)
read -rp "AD test username (no domain): " T; read -rsp "AD test password: " P; echo
docker compose exec -e AD_T="$T" -e AD_P="$P" api bin/rails runner \
  'p Authentication::LdapAuthenticator.call(username: ENV.fetch("AD_T"), password: ENV.fetch("AD_P"))'
unset T P
```

Repeat A to C for `prtauthpro2` and `prtauthpro3`. Run D once. **Never repeat wrong passwords against real accounts: AD
locks them.**

| What you see | What it means | Next step |
|---|---|---|
| A prints nothing | DNS cannot resolve the name: wrong FQDN, or this server has no route to the DNS | AD/DNS team |
| B: `Connection refused` straight away | The host answers but nothing listens on that port | AD team: is LDAPS enabled, and on which port (3269, 636)? |
| B: no answer for 5 s | A firewall or route drops it | Network/firewall team |
| C connects, then `wrong version number`, `unexpected eof` or no certificate | The port is not speaking TLS (plaintext LDAP, or LDAPS is not operational) | AD team |
| C: `unable to get local issuer certificate` or `self-signed certificate in certificate chain` | The certificate is not trusted by the system store | Get the CA from the AD team, repeat with C', then set `AD_CA_FILE` |
| C: `certificate has expired` | The AD certificate expired | AD/PKI team |
| C: `Hostname mismatch` | The certificate does not name that FQDN | Ask the AD team for the correct FQDN or SAN; do not use an IP |
| C: `Verification: OK` | TLS is trusted and the name matches. **This does not prove the bind will succeed.** | Run D |
| D: `Success(:authenticated)` | The bind worked | Done for that account |
| D: `Failure(:invalid_credentials)` | AD was reached over verified TLS and refused the account or password | Check the account and the bind format (`AD_BIND_FORMAT`) |
| D: `Failure(:directory_unavailable)` | See the `ad.directory_unavailable` log line, below | |

The log line `ad.directory_unavailable` has `reason` (the exception class, or `misconfigured` with the `problems` list)
and, for a refused certificate, `tls` with one of: `untrusted_certificate`, `certificate_expired`, `hostname_mismatch`,
`certificate_not_yet_valid`, `certificate_rejected`. No `tls` field means the failure was not a certificate check
(network, timeout, an unexpected LDAP result code). The log never contains the password, the account, the server
address or OpenSSL's own message.

## Values still awaiting the AD and infrastructure teams

Candidate configuration (proposed, **not** proven reachable):

```dotenv
AD_HOST=prtauthpro1.mprt.eg.gov.bn,prtauthpro2.mprt.eg.gov.bn,prtauthpro3.mprt.eg.gov.bn
AD_PORT=3269
AD_NETBIOS_DOMAIN=MPRT
AD_DNS_DOMAIN=MPRT.EG.GOV.BN
AD_BIND_FORMAT=netbios
AD_CA_FILE=
```

| Still to confirm | Why it matters |
|---|---|
| The three FQDNs resolve from the backend server, and the certificates name them | The host name is verified; the supplied IPs (10.112.12.13, 10.112.12.17, 10.240.64.16) are for the firewall only and are rejected as `AD_HOST` |
| LDAPS is operational on 3269 (Global Catalog) on all three, or the right port (636) | The firewall document lists 3268/3269; only the TLS port is used, never 3268/389 |
| `MPRT\name` or `name@MPRT.EG.GOV.BN` (`AD_BIND_FORMAT`) | Demonstrated with a test account |
| Whether the AD certificate chains to a CA in the system store | Decides if `AD_CA_FILE` is needed at all |
| Firewall rule from the backend server to all three hosts | Opened by the network team |
| A dedicated AD test account (and a disabled and a locked one) | For step D and the 401 cases, without risking real accounts |

## How a sign-in is decided

`POST /api/v1/auth/sign_in` goes to a Warden strategy (`Authentication::ActiveDirectoryStrategy`) placed ahead of the
local-password one. It asks `Authentication::OfficerLogin`, which finds the staff user, refuses one that is not `active`
or is discarded (the directory is not asked), then checks the password with `LdapAuthenticator` (production) or
`MockLdapAuthenticator` (local, staging). The code walkthrough, diagrams and the reasons are in
[`docs/active-directory/`](../active-directory/README.md), starting with
[03-code-walkthrough.md](../active-directory/03-code-walkthrough.md).

| Outcome | HTTP | Body |
|---|---|---|
| Signed in | 200 | The existing sign-in response and JWT |
| Unknown user, wrong password, inactive or discarded staff, ambiguous username | 401 | The same generic Devise body for all of them, so nothing says whether the account exists |
| Directory unavailable or misconfigured | 503 | `{"status":"fail","message":"Sign-in is temporarily unavailable. Please try again later."}` |

Operational facts worth knowing without reading the code:

- A person may type `Azri.Nizam`, `MPRT/Azri.Nizam` or `MPRT\azri.nizam`; all find the user stored as `mprt/azri.nizam`.
  The name sent to AD always comes from the stored username.
- Staff have no DoFi password: none is required or stored, and a local password is never accepted.
- The real directory is reached over LDAPS only, with certificate and host-name verification (TLS 1.2 or newer). A wrong
  password is not replayed on every domain controller, which would multiply AD's lockout counter.
- Every decision logs `ad.login` (mode, outcome, reason, user id, duration) and every directory failure logs
  `ad.directory_unavailable` (exception class or LDAP result code). Passwords and AD's own messages are never logged.

## Sign-out and token revocation

Tokens are JWTs whose `jti` must equal `users.jti` (devise-jwt's `JTIMatcher`); replacing `users.jti` kills every token
issued before. Details and tests: [05-token-revocation-and-security.md](../active-directory/05-token-revocation-and-security.md).

| Event | Old tokens |
|---|---|
| Sign-out | Revoked (once) |
| User becomes `inactive`, `suspended` (Fisherman: `suspended`, `revoked`), or is discarded | Revoked, and the user is refused on every request |
| User is re-enabled or undiscarded | Stay dead; the person signs in again |
| `username` changes | Revoked |
| Name, position, unit, contact number, email or locale change | Unaffected |

A refused token answers 401 with the same generic body as any other invalid token. One `jti` exists per user, so
signing out on one device ends every session of that user (existing behaviour).

### What the frontend must do (the frontend repository is not part of this change)

- On sign-out, call `DELETE /api/v1/auth/sign_out`, then clear the stored JWT and the authentication state whatever the
  response was (including a 401: that token is already dead).
- Treat **any 401** from an authenticated call as "this token is no longer valid": clear the stored JWT and state and show
  the sign-in page.
- Show the sign-in 503 message as "sign-in temporarily unavailable", not as wrong credentials.

## Seeding

`db/seeds/admin_user.rb` creates `admin@dofi.gov.bn` once and never touches an existing user. The account has no password.

- Local, test, staging: the username defaults to `mprt/dof-001` (any name works with the mock password), or
  `ADMIN_AD_USERNAME` if set.
- Production: `ADMIN_AD_USERNAME` is **required** and must be a real AD name; otherwise the seed aborts and says so. Nothing
  is bootstrapped with a placeholder.
- `db/seeds.rb` seeds reference data everywhere but the demo data (demo companies, vessels, crews, manifests and the
  Fisherman and Jetty Manager users with the known default password `ChangeMe123!`) only outside production, using
  `DEPLOY_ENV`. There is no switch to turn it on in production.

An existing database is not changed by seeding. To map an existing staff user to its real AD name (for example the
seeded `MPRT/DOF-001` placeholder, or after a staff change):

```bash
docker compose run --rm api bin/rails admin:assign_ad_username EMAIL=admin@dofi.gov.bn AD_USERNAME=mprt/real.name
```

It only accepts staff, checks the name, refuses one already used by another user, and (as with any username change)
revokes that user's tokens.

## Production cut-over (controlled)

Do these in order. The app will not boot on production until step 3 is done, by design.

1. The AD team confirms the DNS names, the LDAPS port and the bind format (see the requirements document), and says
   whether a CA file is needed (usually settled by the checks above). Open the firewall to those hosts and the port from
   the backend server.
2. Pull the new image and compose file. The compose file sets `DEPLOY_ENV=production`. The deploy's `db:prepare` also runs
   `BlankStaffEncryptedPasswords`, which clears every stored staff password hash (including the published default one on
   the seeded superadmin).
3. In the server `.env` set `AD_MODE=ldap`, `AD_HOST`, `AD_PORT`, `AD_NETBIOS_DOMAIN`, `AD_BIND_FORMAT` (and
   `AD_DNS_DOMAIN`; `AD_CA_FILE` with its volume mount only if the checks above show the system store is not enough). Do **not** set `AD_MOCK_PASSWORD`.
4. **Map every staff user to its AD name**, before anyone signs in: the username must be `mprt/<AD name>`. For the
   superadmin run `admin:assign_ad_username` (above) with its real AD name, and check the others in User Management or with
   the same task. A wrong username is a lockout.
5. Remove the demo data that an earlier `db:prepare` seeded on this server (demo companies, vessels, manifests and the
   Fisherman/Jetty Manager users with `ChangeMe123!`). New databases no longer get it (see Seeding).
6. Start the `api` container and test from inside it with a dedicated AD test account and its matching DoFi user
   (disabled, locked and expired-password accounts must get 401). Do not repeat wrong passwords against real accounts: AD
   locks them.
   Use the checks in "Verifying LDAPS from the backend container".
7. Tell the staff. Rollback is to stop the container: there is no local-password mode to fall back to.

## Emergency access when AD is down

There is **deliberately no application bypass**: staff have no local password, the mock is refused on production, and no
flag turns either on. While AD is unreachable, staff sign-in returns 503 and Fishermen and Jetty Managers are
unaffected.

1. **Detect.** 503 responses from sign-in and `ad.directory_unavailable` log entries (the reason is the exception class
   or result code).
2. **Triage** from the API container: DNS and TCP to each `AD_HOST:AD_PORT`, the certificate chain and expiry
   (see "Verifying LDAPS from the backend container"), the CA file if one is set, the clock. The `AD_HOST` list already fails over between domain controllers.
3. **Escalate** to the AD owner and the network/firewall owner (contacts are in the requirements document).
4. **If a business-critical fix cannot wait**, use the controlled server path, not the application: a two-person,
   ticketed console session on the backend server through Delinea (the only way into the client's servers), with the
   session recorded and the change written up afterwards. That session fixes the cause or does the specific data change;
   it does not create a way to sign in.
5. **After recovery**, confirm sign-in, review the log for the outage window and record the cause.

If the client needs an in-application break-glass account (a locally authenticated emergency user), that is a separate
design that needs Security's approval (storage in the secret vault, monitoring, rotation, audit). It is **not** built
here, and it must not reuse `AD_MODE=mock`.

## Known gaps

- There is no per-username login throttle, so someone can lock an AD account by repeatedly submitting wrong passwords.
  The existing 10 per minute per IP limit applies. Add one once Security has set the limits.
- Timing differs slightly between staff (an AD round trip) and unknown users. Status and body are identical.
- Open with the client: MFA, seamless SSO, AD group gating, how fast a disabled AD user must lose access in AD itself (DoFi
  revokes its own tokens as soon as the DoFi user is deactivated, but cannot see an AD-side change until the next
  sign-in), and the in-app break-glass decision above.
