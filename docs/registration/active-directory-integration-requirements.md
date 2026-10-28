# Active Directory Integration: Required Information

## Purpose

This document is the information-request checklist for integrating DoFi Officer login with the
MPRT Active Directory (AD). Complete it with the AD, network, security, frontend, and DoFi product
owners before implementation begins.

This document covers authentication only. AD proves the officer's identity; the DoFi PostgreSQL
database remains authoritative for account status, role, permissions, and application profile. The
first release must use pre-provisioned DoFi users and must not create users or assign DoFi roles from
AD automatically.

Fisherman and Jetty Manager authentication through BruneiID is outside this integration and must
remain unchanged.

How the integration is built and operated is in [active-directory-login.md](active-directory-login.md).

## 1. Confirmed authentication method: LDAPS

DoFi will use LDAPS: the DoFi login form accepts the officer's AD username and password, the backend
validates those credentials against Active Directory over TLS, and DoFi issues its existing JWT after
successful authentication.

| Item | Required answer | Owner | Status |
|---|---|---|---|
| Authentication experience | **LDAPS:** the DoFi login form accepts the AD username and password | Product + AD/Security | **Confirmed** |
| MFA required? | Yes/No, and which system enforces it | Security | **Missing** |
| Windows seamless SSO required? | Yes/No | Product + AD | **Missing** |
| Conditional Access required? | Yes/No | Security | **Missing** |

LDAPS does not itself provide browser-based Microsoft SSO, Conditional Access, or an interactive MFA
flow. If any of those are mandatory, the identity design must be revisited with the AD/security team
before development continues.

## 2. Directory endpoints

The following values came from the initial infrastructure screenshot. The AD owner must confirm that
these are domain controllers providing LDAP and that their complete DNS names are correct.

| Domain | Hostname from screenshot | Proposed FQDN | IP address | Confirmed AD/LDAP server? | Secure LDAP endpoint status |
|---|---|---|---|---|---|
| `MPRT.EG.GOV.BN` | `PRTAUTHPRO1` | `PRTAUTHPRO1.MPRT.EG.GOV.BN` | `10.112.12.13` | Missing | Not present in the supplied firewall extract |
| `MPRT.EG.GOV.BN` | `PRTAUTHPRO2` | `PRTAUTHPRO2.MPRT.EG.GOV.BN` | `10.112.12.17` | Missing | Firewall extract lists `3268/3269`; use and confirm TLS on `3269` |
| `MPRT.EG.GOV.BN` | `PRTAUTHPRO3` | `PRTAUTHPRO3.MPRT.EG.GOV.BN` | `10.240.64.16` | Missing | Firewall extract lists `3268/3269`; use and confirm TLS on `3269` |

Required endpoint information:

| Item | Example/expected value | Owner | Status |
|---|---|---|---|
| AD DNS domain | `MPRT.EG.GOV.BN` | AD | Provisionally known; confirm |
| NetBIOS domain | For example, `MPRT` | AD | Missing |
| Directory base DN | For example, `DC=MPRT,DC=EG,DC=GOV,DC=BN` | AD | Missing |
| LDAPS port | Standard directory LDAPS is `636`; the supplied firewall extract instead identifies Global Catalog ports `3268/3269` | AD | Partially known; confirm `3269` |
| Global Catalog needed? | The firewall extract suggests yes; encrypted Global Catalog is TCP `3269` | AD | Provisionally yes; confirm |
| Production endpoint list | Complete FQDNs in preferred order | AD | Missing |
| Non-production endpoint list | Complete FQDNs and IPs | AD | Missing |
| DNS resolver | DNS server(s) the API container must use | Network | Missing |
| Expected failover order | Ordered hosts, DNS round robin, or load-balanced name | AD + Network | Missing |

The application must connect using a DNS name covered by the server certificate, not a raw IP
address. IP addresses are recorded for routing and firewall diagnosis only.

## 3. Username and identity mapping

Provide examples using non-sensitive test identities. Do not provide a real user's password in this
document.

| Item | Example/choices | Owner | Status |
|---|---|---|---|
| Username entered in DoFi | For example, `dof-001` | Product + AD | Missing |
| LDAP bind-name format | `dof-001@MPRT.EG.GOV.BN`, `MPRT\\dof-001`, or full DN | AD | Missing |
| Login attribute | Usually `userPrincipalName` or `sAMAccountName` | AD | Missing |
| UPN suffix | For example, `MPRT.EG.GOV.BN` | AD | Missing |
| Case handling | Confirm whether login is case-insensitive | AD | Missing |
| Stable AD identifier | Confirm access to `objectGUID` | AD | Missing |
| Display-name attribute | Usually `displayName` | AD | Missing |
| Employee identifier attribute | Attribute name, if DoFi should verify/store it | AD + Product | Missing |
| Email attribute | Usually `mail`, if needed | AD + Product | Missing |

The existing DoFi `users.username` field was originally created for a directory username. For the
first release, every AD user must already have a matching local DoFi user. A successful AD login for
an unknown local username must not create an account.

When available, store the AD `objectGUID` as the durable identity link. Usernames, UPNs, and DNs can
change when a person is renamed or moved in AD.

## 4. Account eligibility and authorization

These are business and security decisions, not directory connection details.

| Item | Required answer | Owner | Status |
|---|---|---|---|
| Eligible population | Which DoFi users authenticate with AD? Recommended: DoFi Officers only | Product + Security | Missing |
| Pre-provisioning owner | Who creates the matching local DoFi account and assigns its role? | Product | Missing |
| AD group gate | Is membership in a particular AD group required? If yes, provide its exact immutable identifier and group type | AD + Security | Missing |
| Nested groups | Should nested group membership count? | AD + Security | Missing |
| Role source | Recommended: local DoFi role only, never an automatic role derived from arbitrary AD attributes | Product + Security | Missing |
| Local inactive user | Recommended: deny login even if AD authentication succeeds | Product + Security | Missing |
| AD-disabled user | Recommended: deny login | Security | Missing |
| AD-locked user | Recommended: deny login | Security | Missing |
| Expired password | Deny login, or redirect the user to the organization's password-change process | AD + Product | Missing |
| Deleted/terminated user | State how quickly DoFi access must be revoked | Security | Missing |

If group membership is not required, direct user binding can authenticate without a directory search
service account. Reading `objectGUID`, profile attributes, or groups may require a read-only service
account, depending on AD policy.

## 5. TLS certificates

LDAPS is mandatory for an LDAP password flow. Do not send a user's password through an unencrypted
simple bind on TCP 389, and do not disable certificate verification.

Provide:

| Item | Required data | Owner | Status |
|---|---|---|---|
| Root CA | PEM/CRT certificate used to validate the LDAPS server certificate | PKI/AD | Missing |
| Intermediate CA chain | Every required intermediate certificate in PEM/CRT form | PKI/AD | Missing |
| Certificate DNS names | Subject Alternative Names for each endpoint/load-balanced name | PKI/AD | Missing |
| Certificate expiry | Current expiry date and renewal owner/process | PKI/AD | Missing |
| Minimum TLS version | Organization-approved version, normally TLS 1.2 or newer | Security | Missing |
| Certificate delivery | Approved secure method and target path in the API container | DevOps + Security | Missing |

CA certificates are public trust material and may be distributed through the approved deployment
configuration. Private keys must never be provided to DoFi; an LDAPS client does not need the domain
controller's private key.

## 6. Network and firewall information

Provide one row for every environment.

| Environment | API source IP/NAT IP | Destination FQDNs/IPs | Port/protocol | DNS available? | Firewall owner/ticket |
|---|---|---|---|---|---|
| Local/development | Missing | Non-production AD only | TCP 3269 if it also uses Global Catalog LDAPS; confirm | Missing | Missing |
| Test | Missing | Non-production AD only | TCP 3269 if it also uses Global Catalog LDAPS; confirm | Missing | Missing |
| Staging | Missing | Non-production AD preferred | TCP 3269 if it also uses Global Catalog LDAPS; confirm | Missing | Missing |
| Production | `10.252.8.11` | `10.112.12.17` (`PRTAUTHPRO2`, proposed) | Firewall row lists TCP `3268/3269`; application must use TLS on `3269` | Missing | Ticket/reference missing |
| Production | `10.252.8.11` | `10.240.64.16` (`PRTAUTHPRO3`, proposed) | Firewall row lists TCP `3268/3269`; application must use TLS on `3269` | Missing | Ticket/reference missing |

The supplied firewall extract labels these paths "App Server to AD Server" and includes both Global
Catalog ports. TCP `3268` is the non-TLS Global Catalog service; TCP `3269` is the TLS-protected
Global Catalog service. Because this integration is confirmed as LDAPS, DoFi must use `3269`, must
validate the server certificate, and must not fall back to `3268`. The AD/network team must still
confirm that TLS is actually configured on both destinations and that `10.252.8.11` is the source IP
seen by the firewall when traffic originates inside the API container.

The firewall extract does not show a rule for `PRTAUTHPRO1` (`10.112.12.13`). Confirm whether that
server is intentionally excluded or whether an equivalent TCP `3269` rule is still required.

Also provide:

- Routing/VPN requirements between the application network and both AD subnets.
- Whether container traffic is NATed to a different source IP than the host.
- DNS search domains and resolvers visible inside the API container.
- Firewall idle timeout or connection limitations relevant to LDAPS.
- The network and AD contacts for an outage.

Connectivity must be tested from inside the running API container. A successful connection from a
developer laptop or only from the Docker host is not sufficient evidence.

## 7. Test accounts and expected results

The AD team should create dedicated, non-production identities. Do not reuse real employee accounts
for automated testing.

| Test identity | Required state | Expected DoFi result | Provided? |
|---|---|---|---|
| AD test user 1 | Active, correct password | Login succeeds for a matching active local officer | Missing |
| AD test user 2 | Disabled | Login denied | Missing |
| AD test user 3 | Locked | Login denied | Missing |
| AD test user 4 | Password expired | Agreed expired-password response | Missing |
| AD test user 5 | Active but not in the allowed AD group, if a group gate is used | Login denied | Missing |
| AD test user 6 | Active and in a nested allowed group, if nested groups are supported | Agreed result | Missing |

For each test identity, provide through an approved secure channel:

- Username, UPN, and `sAMAccountName`.
- Expected `objectGUID` if identity lookup is in scope.
- Expected group membership if group gating is in scope.
- Temporary password and expiry instructions.
- Permission to deliberately test wrong-password behavior.

Coordinate lockout testing with the AD team. Automated tests must not repeatedly submit bad
passwords to real AD accounts.

## 8. Service account, only if directory search is required

Complete this section only if DoFi must search for users or groups before/after authenticating them.

| Item | Required data | Owner | Status |
|---|---|---|---|
| Service-account bind name | UPN or DN | AD | Not yet required/undecided |
| Secret delivery | Secret-vault reference, never plaintext in Git or this document | Security + DevOps | Undecided |
| Search base | Exact DN | AD | Undecided |
| Permitted attributes | Minimum set, for example `objectGUID`, `userPrincipalName`, `displayName`, `memberOf` | AD + Security | Undecided |
| Group search base | Exact DN, if different | AD | Undecided |
| Password rotation | Rotation interval, owner, alerting, and deployment procedure | AD + DevOps | Undecided |
| Restrictions | Read-only; no create, update, delete, password-reset, or privileged directory permissions | Security | Required if created |

Prefer direct user bind for phase one if no searches are required. This avoids introducing a shared
directory credential solely for password validation.

## 9. Security and session decisions

| Item | Required answer | Owner | Status |
|---|---|---|---|
| AD lockout policy | Threshold and observation/reset window | AD + Security | Missing |
| Login rate limit | Requests per user and per source IP | Security | Missing |
| LDAP timeouts | Recommended starting point: 3-second connection, 5-second operation | DevOps + AD | Missing |
| Host failover rule | Retry only connection/TLS/timeout failures; never retry invalid credentials across all hosts | Security + AD | Missing |
| Error disclosure | Recommended: one generic `401` for unknown/invalid/disabled/locked accounts; `503` only when the directory is unavailable | Security + Product | Missing |
| Officer JWT lifetime | Current application default is one day; approve or shorten it | Security + Product | Missing |
| AD disablement propagation | How an already-issued JWT is revoked after an AD user is disabled | Security + Product | Missing |
| Local status enforcement | Require current local `active` and non-discarded state on login and authenticated requests | Security + Product | Missing |
| Break-glass accounts | Number, custodians, vault location, monitoring, test and rotation schedule | Security + Operations | Missing |
| Audit retention | Successful/failed authentication metadata retention period | Security | Missing |
| PII in logs | Confirm approved username/user-ID logging or pseudonymization policy | Security | Missing |

The application must never fall back to an old local password after AD rejects an AD-managed user.
Any emergency local administrator must be explicitly marked as locally authenticated, tightly
controlled, audited, and stored in the organizational secret vault.

## 10. Frontend and API contract decisions

| Item | Required answer | Owner | Status |
|---|---|---|---|
| Login identifier label | `Username`, `AD username`, or organization-approved wording | Product + Frontend | Missing |
| Username format shown to user | Short name, UPN, or domain-qualified name | Product + AD | Missing |
| Password-expired UX | Generic denial or link/instruction for the approved password-change process | Product + AD | Missing |
| Directory outage UX | User-facing message for HTTP `503` | Product | Missing |
| Existing endpoint retained? | Recommended: keep `POST /api/v1/auth/sign_in` and its current JWT response | Backend + Frontend | Missing |
| BruneiID separation | Confirm Fisherman/Jetty Manager login is unchanged | Product | Missing |

## 11. Monitoring and operational ownership

Provide:

- AD service owner and escalation contact.
- Network/firewall escalation contact.
- PKI/certificate renewal contact.
- DoFi application on-call contact.
- Planned AD maintenance windows.
- Expected normal and maximum authentication latency.
- Alert thresholds for directory unavailability, TLS failure, and elevated login failures.
- The incident procedure when all directory servers are unavailable.

Safe authentication logs may contain request ID, local user ID when known, selected directory host,
result category, and duration. They must not contain passwords, bind payloads, access tokens, full
certificate contents, or unrestricted AD diagnostic messages.

## 12. Minimum information needed before development starts

Development is ready to start when all of these are available:

- [x] Authentication method confirmed: LDAPS.
- [ ] Exact non-production and production endpoint FQDNs confirmed.
- [ ] Global Catalog LDAPS on TCP `3269` confirmed and reachable from the intended API environment; do not use the listed plaintext TCP `3268` service.
- [ ] AD DNS domain, NetBIOS domain, base DN, UPN suffix, and login attribute confirmed.
- [ ] Required bind-name format demonstrated with a test account.
- [ ] Root/intermediate CA certificate chain supplied and certificate DNS names verified.
- [ ] Firewall source, destination, port, routing, and DNS requirements approved.
- [ ] At least one active non-production test account supplied securely.
- [ ] Disabled/locked/expired-password test behavior agreed.
- [ ] Local pre-provisioning and role-assignment owner identified.
- [ ] AD group-gating decision made.
- [ ] Service-account decision made; least-privilege details supplied if required.
- [ ] Login rate limit and AD lockout policy supplied.
- [ ] JWT lifetime and post-disablement session behavior approved.
- [ ] Break-glass procedure approved.
- [ ] Staging acceptance-test window and responsible participants scheduled.

## 13. Sensitive-data handling

Do not put any of the following in this document, issue trackers, chat transcripts, Git commits,
screenshots, or ordinary email:

- User or service-account passwords.
- Secret-vault values.
- Private keys.
- JWTs or session tokens.
- Production credentials used for connectivity testing.

Record only the approved secret reference and delivery owner. Transfer temporary test passwords using
the organization's approved secure channel, rotate them after shared testing, and remove them when
the integration is accepted.

## 14. Sign-off

| Area | Name/team | Decision/date |
|---|---|---|
| Product owner | Missing | Missing |
| AD/identity owner | Missing | Missing |
| Security | Missing | Missing |
| Network/firewall | Missing | Missing |
| PKI/certificates | Missing | Missing |
| Backend | Missing | Missing |
| Frontend | Missing | Missing |
| DevOps/operations | Missing | Missing |

