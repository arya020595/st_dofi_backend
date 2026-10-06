# Testing BruneiID login

Seeds retain the existing developer and sandbox accounts, including preclaimed test identities.
Those fixtures do not replace provider verification: real login requires a valid OIDC callback.
Developers can enable a separate mock endpoint for local and staging testing.

The app currently runs on staging. External users authenticate through the BruneiID OIDC callback:

```text
POST /api/v1/auth/brunei_id/callback
```

The OIDC callback never trusts a frontend-supplied IC number or falls back to mock login.

## Mock login for local and staging

Set the backend `.env` flag explicitly:

| Environment | `.env` setting |
|---|---|
| Local and staging | `BRUNEIID_MOCK_ENABLED=true` |
| Production | `BRUNEIID_MOCK_ENABLED=false` |

Only the exact value `true` enables the mock. Missing, false, and invalid values disable it.
Staging also runs `RAILS_ENV=production`, so Rails environment does not control this flag.
The setting is read at boot. Recreate the API container after changing it:

```bash
docker compose up -d --force-recreate api
```

To recreate only the API and leave dependencies running, use
`docker compose up -d --no-deps --force-recreate api`.

When enabled, developers can call:

```text
POST /api/v1/auth/brunei_id
```

```json
{ "ic_number": "01-123456", "audience": "fisherman" }
```

Use `jetty_manager` for that audience. This endpoint trusts the supplied IC for development testing,
performs no BruneiID HTTP requests, and shares account lookup, claiming, and status checks with the
real callback. Audience-scoped responses keep the callback shape described below.

For compatibility, omitted or unrecognized audiences keep the original unscoped lookup across
kept users: active accounts receive JWT/realtime tokens and `data.user`; inactive accounts return
200 with user data only, and missing accounts return the translated 404 account-not-found message.
Claimable Fishermen are claimed before login. Missing or blank IC parameters return 400.

When disabled, the mock route is absent and returns 404 without account changes or tokens.
Real OIDC login remains available. Mock events use `brunei_id.mock_authentication` in stdout logs;
they do not represent provider verification.

## Configuration and sign-in

Set `BRUNEIID_BASE_URL`, `BRUNEIID_CLIENT_ID`, `BRUNEIID_CLIENT_SECRET`, and `BRUNEIID_REDIRECT_URI`
in the backend environment. Keep the client secret on the backend. The configured redirect URI
must exactly match the provider's registered frontend callback, including scheme, host, and path.

The frontend generates a PKCE verifier/challenge, nonce, and state and starts authorization using
the provider's discovery document. After the user completes BruneiID sign-in, the frontend checks
state and sends the returned one-use code to the backend with the original verifier and nonce:

```json
{
  "code": "<fresh-authorization-code>",
  "code_verifier": "<original-pkce-verifier>",
  "redirect_uri": "<registered-frontend-callback>",
  "nonce": "<original-nonce>",
  "audience": "fisherman"
}
```

Use `audience: "jetty_manager"` for a Jetty Manager. The backend exchanges the code, verifies the
ID token's signature, issuer, audience, expiry, and nonce, then resolves the verified IC against
only the requested audience. Userinfo is optional when advertised by the provider.

## Expected results

- Provisioned active accounts receive `data.access_token`, `data.user`, realtime tokens, and
  `next_action: "dashboard"`. Use the JWT on `/api/v1/auth/me` to verify the session.
- A claimable Fisherman is claimed before receiving the dashboard session.
- Suspended/revoked Fishermen and inactive Jetty Managers receive a 422 registration-status response.
- An unknown account receives the audience-specific 404 response; login never creates an account.
- Invalid or reused codes, bad PKCE, and invalid ID tokens fail authentication without issuing tokens.
- Supported audiences are `fisherman` and `jetty_manager`; other audiences receive 422.

## Automated and live checks

```bash
bin/rails test test/services/brunei_id test/services/brunei_id_sessions test/controllers/api/v1/brunei_id_sessions_controller_test.rb
bin/rails test test/integration/brunei_id_oidc_login_test.rb
bin/rails test test/integration/brunei_id_mock_login_test.rb
```

Tests use generated RSA signatures and provider doubles at the OIDC boundary. Integration tests
exercise the actual callback route and account lifecycle without making external requests.
The OIDC login integration test substitutes only provider HTTP responses, then runs real signature
validation, account resolution/claiming, serialization, and JWT authentication on `/auth/me`.

Public discovery and JWKS can be checked without credentials. An expected `invalid_grant` response
for a deliberately invalid code checks the negative token-exchange path; it does not prove a
successful user login. Complete sign-in through the staging frontend to test that final path.
Never paste the client secret or complete token responses into logs or issue comments.

View server output with `docker compose logs api -f`; see
[server logging](../operations/server-logging.md).
