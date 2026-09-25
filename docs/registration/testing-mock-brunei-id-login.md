# Testing BruneiID Login

Seeded active Fisherman and Jetty Manager accounts can be exercised through the simulation endpoint:

```sh
curl -X POST "$BASE_URL/api/v1/auth/brunei_id" \
  -H "Content-Type: application/json" \
  -d '{"ic_number":"01-123456","audience":"fisherman"}'
```

For OIDC sandbox testing, complete the authorization-code + PKCE flow in the client, then send the
code, verifier, redirect URI, nonce, and intended audience to
`POST /api/v1/auth/brunei_id/callback`.

Both paths return a DoFi access token only if the matching account is active. Unknown or inactive
accounts return `401 Unauthorized`; there is no registration fallback.
