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
| `AD_CA_FILE` | system trust store | PEM of the CA that issued the directory certificate, as a path inside the container |
| `AD_CONNECT_TIMEOUT` | `3` | Seconds to connect and complete TLS, per host |
| `AD_OPERATION_TIMEOUT` | `5` | Seconds to wait for the bind answer |
| `ADMIN_AD_USERNAME` | mock default outside production, **required in production** | The superadmin's AD username, used only by `db:seed` on a fresh database |

A real-directory configuration that cannot work (missing host, IP address, port 389, unreadable CA file, ...) does not
break boot: it makes staff sign-in return **503** and logs the reasons (`ad.directory_unavailable`). It never falls back
to anything else.

### The CA certificate

The directory's certificate must verify against a CA the container trusts. Put the CA's PEM (public material, no private
key) on the host, mount it read-only into the `api` container (see the commented `volumes:` example in
`deploy/production/backend/docker-compose.yml`) and set `AD_CA_FILE` to the container path. The certificate must name
the `AD_HOST` you configured (subject alternative name), because the host name is checked.

## How a sign-in is decided

```
POST /api/v1/auth/sign_in
  Warden strategy (Authentication::ActiveDirectoryStrategy), first in line
    -> Authentication::OfficerLogin
         DirectoryUsername   what was typed -> the local usernames it could mean
         User.directory_managed   find the staff user (none: not our business, Devise carries on as before)
         eligible?  kept and active, else refuse (the directory is not asked)
         LdapAuthenticator | MockLdapAuthenticator   is the password right?
```

| Outcome | HTTP | Body |
|---|---|---|
| Signed in | 200 | The existing sign-in response and JWT |
| Unknown user, wrong password, inactive or discarded staff, ambiguous username | 401 | The same generic Devise body for all of them, so nothing says whether the account exists |
| Directory unavailable or misconfigured | 503 | `{"status":"fail","message":"Sign-in is temporarily unavailable. Please try again later."}` |

### Usernames

Local usernames are stored the way the Add User form produces them, e.g. `mprt/azri.nizam`. A person may type
`Azri.Nizam`, `MPRT/Azri.Nizam` or `MPRT\azri.nizam`; all find the same user. The name sent to AD always comes from the
matched user's *stored* username (the part after `MPRT/`), never from the typed text. If two users match (for example
`azri.nizam` and `mprt/azri.nizam` both exist) nobody is signed in and the attempt is logged as `ambiguous_username`.

### No local password for staff

Staff have no DoFi password: `User#valid_password?` is always false for them, whatever the username spelling, the mode
or an outage, so Devise's own password check can never admit one. In addition the strategy decides first and a refusal
stops the chain. A random value still sits in `encrypted_password` because Devise requires one; nothing can use it.

### TLS and the directory connection (ldap mode)

`Authentication::LdapAuthenticator` is the only code that talks LDAP. It uses LDAPS with certificate verification
(`VERIFY_PEER`, TLS 1.2 or newer, the host name must match the certificate) and never plaintext. It tries the next host
only when it cannot connect or finish TLS, never after AD rejected a password, so a wrong password is not replayed on
every domain controller (which would multiply AD's lockout counter). A blank password is never sent: an LDAP bind with
an empty password is an unauthenticated bind that many servers accept.

AD answers "invalid credentials" for a wrong password and also for unknown, disabled, locked and expired accounts. DoFi
treats them all as 401, with no distinction.

### Logging

`ad.login` (info or warn): mode, outcome, reason, local user id when known, duration. `ad.directory_unavailable`
(error): the exception class or LDAP result code, never the message. Passwords, bind payloads and AD's own diagnostic
text are never logged.

## Sign-out and token revocation

Tokens are JWTs whose `jti` claim must equal `users.jti` (devise-jwt's `JTIMatcher`). Replacing `users.jti` kills every
token issued before, on every endpoint and for the realtime (WebSocket) token too. No separate revocation mechanism
exists.

| Event | What happens |
|---|---|
| `DELETE /api/v1/auth/sign_out` | devise-jwt's revocation middleware replaces `jti` once. The old token is refused from then on. |
| A user becomes `inactive` or `suspended` (or a Fisherman `suspended`/`revoked`), or is discarded | `User#revoke_tokens` replaces `jti` in the same save, and `User#active_for_authentication?` makes Devise refuse the user on every request (it runs for the JWT strategy too). |
| The account is re-enabled or undiscarded | Nothing is rotated and nothing is restored: tokens issued before stay dead and the person signs in again. |
| A user's `username` (the sign-in identity) changes | `jti` is replaced, so the old session ends. |
| Name, position, unit, contact number, email or locale change | Nothing: live sessions are unaffected. |

A refused token answers 401 with the same generic body as any other invalid token. One `jti` exists per user, so
signing out on one device ends every session of that user (existing behaviour).

### What the frontend must do (the frontend repository is not part of this change)

- On sign-out, call `DELETE /api/v1/auth/sign_out`, then clear the stored JWT and the authentication state whatever the
  response was (including a 401: that token is already dead).
- Treat **any 401** from an authenticated call as "this token is no longer valid": clear the stored JWT and state and show
  the sign-in page.
- Show the sign-in 503 message as "sign-in temporarily unavailable", not as wrong credentials.

## Seeding

`db/seeds/admin_user.rb` creates `admin@dofi.gov.bn` once and never touches an existing user. The account has no usable
password.

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

1. The AD team confirms the DNS names, the LDAPS port, the bind format and supplies the CA PEM
   (see the requirements document). Open the firewall to those hosts and the port from the backend server.
2. Pull the new image and compose file. The compose file sets `DEPLOY_ENV=production`.
3. In the server `.env` set `AD_MODE=ldap`, `AD_HOST`, `AD_PORT`, `AD_NETBIOS_DOMAIN`, `AD_BIND_FORMAT` (and
   `AD_DNS_DOMAIN`, `AD_CA_FILE` with its volume mount). Do **not** set `AD_MOCK_PASSWORD`.
4. **Map every staff user to its AD name**, before anyone signs in: the username must be `mprt/<AD name>`. For the
   superadmin run `admin:assign_ad_username` (above) with its real AD name, and check the others in User Management or with
   the same task. A wrong username is a lockout.
5. Remove the demo data that an earlier `db:prepare` seeded on this server (demo companies, vessels, manifests and the
   Fisherman/Jetty Manager users with `ChangeMe123!`). New databases no longer get it (see Seeding).
6. Start the `api` container and test from inside it with a dedicated AD test account and its matching DoFi user
   (disabled, locked and expired-password accounts must get 401). Do not repeat wrong passwords against real accounts: AD
   locks them.
   ```bash
   openssl s_client -connect <AD_HOST>:<AD_PORT> -servername <AD_HOST> -CAfile /etc/dofi/ad-ca.pem </dev/null | head -20
   ```
7. Tell the staff. Rollback is to stop the container: there is no local-password mode to fall back to.

## Emergency access when AD is down

There is **deliberately no application bypass**: staff have no local password, the mock is refused on production, and no
flag turns either on. While AD is unreachable, staff sign-in returns 503 and Fishermen and Jetty Managers are
unaffected.

1. **Detect.** 503 responses from sign-in and `ad.directory_unavailable` log entries (the reason is the exception class
   or result code).
2. **Triage** from the API container: DNS and TCP to each `AD_HOST:AD_PORT`, the certificate chain and expiry
   (`openssl s_client`), the CA file, the clock. The `AD_HOST` list already fails over between domain controllers.
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
