# Issue: 405 on `/api/v1/auth/sign_in` from admin login (staging)

## Symptom

Logging in from the staging admin frontend fails with:

```
POST http://217.217.252.45:4100/api/v1/auth/sign_in 405 (Not Allowed)
```

## Root cause

The frontend at `http://217.217.252.45:4100/admin/login` is sending its login POST request to
its own host/port instead of the backend:

```
http://217.217.252.45:4100/api/v1/auth/sign_in   ← wrong (frontend's own host/port)
http://46.202.163.155:3012/api/v1/auth/sign_in   ← correct (staging API)
```

These are two different servers. Port `4100` serves the frontend app, not Rails. When the
frontend calls its own origin at that path, whatever answers there (static file server / SPA
host) has no POST handler for `/api/v1/auth/sign_in`, so it correctly returns
`405 Method Not Allowed`. **The Rails backend never receives this request** — this is not a
routing, CORS, or backend bug. The route exists and works as expected
(`devise_for :users, path: "api/v1/auth"` in `config/routes.rb` registers
`POST /api/v1/auth/sign_in`).

The frontend's API base URL is misconfigured — it's either unset or defaulting to the
frontend's own origin instead of pointing at the backend.

## Fix — frontend team

Set the frontend's API base URL env var (e.g. `VITE_API_URL` / `NEXT_PUBLIC_API_URL`, whatever
it's called in that project) to:

```
http://46.202.163.155:3012
```

for the staging build/deploy, then rebuild/redeploy.

## Fix — backend team (follow-up, once frontend is fixed)

Once the frontend correctly calls the backend cross-origin, the browser will need CORS to allow
it. On the staging server's `.env` (not committed to the repo), make sure `CORS_ORIGINS` includes
the frontend's origin:

```
CORS_ORIGINS=http://217.217.252.45:4100,<any other staging frontend origins>
```

Then restart the `api` container so rack-cors picks it up (it only reads this at boot). See the
comment at the top of `docker-compose.staging.yml`.

## How to verify

Once both fixes are deployed, logging in from `http://217.217.252.45:4100/admin/login` should
show the browser calling `http://46.202.163.155:3012/api/v1/auth/sign_in` in devtools Network
tab, returning `200`/`401` (not `405`), with no CORS error in the console.
