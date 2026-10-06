# Server logging

The app currently runs on staging. Rails uses `RAILS_ENV=production` there and writes logs to stdout.
View them on the staging backend server:

```bash
docker compose logs api -f
```

For background jobs:

```bash
docker compose logs jobs -f
```

Press Ctrl+C to stop following; the containers keep running. Application request and response bodies
are no longer copied into a database. Rails/Lograge request summaries, framework errors, Sentry,
and business audit records remain available.

## Connect to the correct deployment

Use your assigned SSH account and server address:

```bash
ssh <user>@<backend-server>
```

On staging, run commands from `/home/stadmin/st_dofi_backend_staging`. Deployment renames the
Compose file to `docker-compose.yml`, so the command above works directly.

Production has not launched. Its deployment workflow keeps `docker-compose.production.yml`;
when that environment is used, select it explicitly with
`docker compose -f docker-compose.production.yml logs api jobs -f`.

## Write application events

Use the shared service for operational events:

```ruby
ApplicationLogger.call(
  event: "brunei_id.authentication",
  level: :warn,
  params: { audience: "fisherman", outcome: "failure", reason: "invalid_code" }
)
```

Each event has a JSON payload on one line with `timestamp` (UTC), `level`, `event`, `request_id`, `user_id`,
and `params` (Rails may prefix its configured request tag). Use fixed dotted event names and a small
Hash of safe operational values. Request IDs
come from the current request and are cleared afterward. Jobs can pass `request_id:` explicitly;
pass `user_id:` only when an internal account ID helps diagnose the operation.

Supported levels follow `RAILS_LOG_LEVEL`: `debug` for temporary diagnostics, `info` (the default)
for successful operations, `warn` for expected failures that need investigation, `error` for failed
operations/configuration, and `fatal` for an unusable process. Rails/Lograge already writes request
summaries, so avoid duplicating them.

The service applies Rails parameter filters plus personal-data and raw-body/header filters,
including nested Hashes and arrays. Never pass entire requests, provider responses, exception
messages, or secrets in event names or arbitrary text fields: key-based filtering cannot identify
sensitive values under an unrelated key. BruneiID logs only audience, outcome, failure reason,
and internal account ID. Output IO failures do not change the authentication result.
Enabled developer mock login uses the separate `brunei_id.mock_authentication` event. Its `kind`
identifies dashboard or status-only results; it is not proof of real BruneiID verification.

## Troubleshooting

```bash
docker compose ps
docker compose logs --since 15m --tail 200 --timestamps api jobs
docker compose logs --since 1h --no-color api | rg -F '<request-id>'
```

The response's `X-Request-Id` identifies a request in the Rails/Lograge output. If `rg` is unavailable,
use `grep -F`.

Docker controls local log storage. Logs may disappear when containers are replaced or removed.
No new rotation policy or logging infrastructure is introduced by this change.

For temporary troubleshooting, set `RAILS_LOG_LEVEL=debug` in the server's `.env` and recreate only
the affected service with `docker compose up -d --no-deps --force-recreate api`. Restore `info` afterward.
Debug output can include sensitive data; parameter filtering remains enabled at every log level.

See [log management](log-management.md) for future centralization.
