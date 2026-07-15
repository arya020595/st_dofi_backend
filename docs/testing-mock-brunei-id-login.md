# Testing Fisherman / Jetty Manager Login via Mock BruneiID

A practical, copy-pasteable walkthrough for exercising the Fisherman/Jetty Manager "login" flow
locally or on staging. For the full request/response contract, see
[`registration-flow.md`](registration-flow.md) section 6 ("Mock BruneiID Login") — this doc is the
step-by-step companion to it.

## Why a mock

Fishermen and Jetty Managers have no username/password login screen — only a registration form.
In production, "logging in" again is a BruneiID QR re-scan on the frontend, an external system DoFi
doesn't control. There's no real BruneiID integration or test credentials available yet, so
`POST /api/v1/auth/brunei_id` (`app/services/brunei_id/client.rb`) stands in for it: given an
`ic_number`, it trusts the identity as already verified — the same trust boundary registration
itself already relies on — and looks up the matching `User`. This lets FE/QA exercise the full
register → approve → login loop today, without waiting on the real BruneiID integration.

DoFi Officer/Administrator accounts are unaffected by any of this — they keep logging in with
`POST /api/v1/auth/sign_in` and a real `username`/`password`.

## Prerequisites

```bash
BASE_URL=http://localhost:3000   # or the staging base_url from postman/DoFi-Backend-Staging.postman_environment.json
```

`jq` is used below to pull fields out of responses — install it (`apt install jq` / `brew install
jq`) or just read the raw JSON by eye instead.

You'll need an authenticated **officer** session first, since approving/rejecting registrations is
an officer-only action (`fisherman_approvals.approve` / `jetty_manager_approvals.approve`
permission — the seeded admin has both via full access):

```bash
OFFICER_TOKEN=$(curl -s -D - -o /dev/null -X POST "$BASE_URL/api/v1/auth/sign_in" \
  -H "Content-Type: application/json" \
  -d '{"user": {"username": "mprt/dof-001", "password": "ChangeMe123!"}}' \
  | grep -i '^Authorization:' | tr -d '\r' | cut -d' ' -f2-)

echo $OFFICER_TOKEN   # should start with "Bearer "
```

(`mprt/dof-001` / `ChangeMe123!` are the seeded defaults — see `db/seeds/admin_user.rb` — swap in
whatever `ADMIN_DEFAULT_USERNAME`/`ADMIN_DEFAULT_PASSWORD` was actually deployed for that
environment.)

---

## Part A — Fisherman: full happy path (`active`)

**1. Profile, as the officer.** Every registration type — including Small - Scale (Full-Time) —
must already be profiled before the fisherman can register (see `registration-flow.md` §5). For
Full-Time, that means an individual-shaped `CompanyProfile` with just an Owner contact (the
fisherman themselves) and no company-shape fields:

```bash
curl -s -X POST "$BASE_URL/api/v1/company_profiles" \
  -H "Authorization: $OFFICER_TOKEN" -H "Content-Type: application/json" \
  -d '{
    "company_profile": {
      "registration_type": "Small - Scale (Full-Time)",
      "owner": { "full_name": "Test Fisherman (Active)", "gender": "Male",
                 "ic_no": "01-800201", "ic_colour": "Yellow" }
    }
  }' | jq .
```

**2. Register.**

```bash
curl -s -X POST "$BASE_URL/api/v1/registrations/fisherman" \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "name": "Test Fisherman (Active)",
      "ic_number": "01-800201",
      "registration_type": "Small - Scale (Full-Time)"
    }
  }' | tee /tmp/fisherman.json | jq .

FISHERMAN_ID=$(jq -r '.data.id' /tmp/fisherman.json)
```

Status is `pending` at this point — the fisherman cannot log in yet.

**3. Approve, as the officer.**

```bash
curl -s -X POST "$BASE_URL/api/v1/approvals/fishermen/$FISHERMAN_ID/approve" \
  -H "Authorization: $OFFICER_TOKEN" | jq .
```

Response `data.status` is now `"active"`.

**3. "Log in" via mock BruneiID.**

```bash
curl -s -D - -X POST "$BASE_URL/api/v1/auth/brunei_id" \
  -H "Content-Type: application/json" \
  -d '{"ic_number": "01-800201"}'
```

For an `active` user this returns the same shape as the officer sign-in: `data.access_token` is
present, and the `Authorization` response header carries the same token. Capture it the same way as
the officer token above:

```bash
FISHERMAN_TOKEN=$(curl -s -D - -o /dev/null -X POST "$BASE_URL/api/v1/auth/brunei_id" \
  -H "Content-Type: application/json" -d '{"ic_number": "01-800201"}' \
  | grep -i '^Authorization:' | tr -d '\r' | cut -d' ' -f2-)
```

**4. Use it — confirm it's really a working session.**

```bash
curl -s "$BASE_URL/api/v1/auth/me" -H "Authorization: $FISHERMAN_TOKEN" | jq .
```

Returns the fisherman's own `User` record. Any endpoint the Fisherman role has permission for
works the same way — just send `Authorization: $FISHERMAN_TOKEN`.

---

## Part B — Jetty Manager: full happy path (`active`)

Same shape, different registration endpoint and required fields (`unit`/`position`/`contact_no`
instead of `registration_type`):

```bash
curl -s -X POST "$BASE_URL/api/v1/registrations/jetty_manager" \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "name": "Test Jetty Manager (Active)",
      "ic_number": "01-800301",
      "unit": "Docks",
      "position": "Jetty Supervisor",
      "contact_no": "71111111"
    }
  }' | tee /tmp/jetty_manager.json | jq .

JETTY_MANAGER_ID=$(jq -r '.data.id' /tmp/jetty_manager.json)

curl -s -X POST "$BASE_URL/api/v1/approvals/jetty_managers/$JETTY_MANAGER_ID/approve" \
  -H "Authorization: $OFFICER_TOKEN" | jq .

curl -s -D - -X POST "$BASE_URL/api/v1/auth/brunei_id" \
  -H "Content-Type: application/json" \
  -d '{"ic_number": "01-800301"}'
```

---

## Testing the other outcomes

**Pending** — profile, register, but skip the approve step, then hit the login endpoint anyway:

```bash
curl -s -X POST "$BASE_URL/api/v1/company_profiles" \
  -H "Authorization: $OFFICER_TOKEN" -H "Content-Type: application/json" \
  -d '{
    "company_profile": {
      "registration_type": "Small - Scale (Full-Time)",
      "owner": { "full_name": "Test Fisherman (Pending)", "gender": "Male",
                 "ic_no": "01-800202", "ic_colour": "Yellow" }
    }
  }' | jq .

curl -s -X POST "$BASE_URL/api/v1/registrations/fisherman" \
  -H "Content-Type: application/json" \
  -d '{"user": {"name": "Test Fisherman (Pending)", "ic_number": "01-800202",
                 "registration_type": "Small - Scale (Full-Time)"}}' | jq .

curl -s -X POST "$BASE_URL/api/v1/auth/brunei_id" \
  -H "Content-Type: application/json" -d '{"ic_number": "01-800202"}' | jq .
```

Returns **200 OK**, `data.status: "pending"`, **no** `access_token` — same shape as
`GET /api/v1/registrations/status`, so the FE can reuse its existing pending-status screen.

**Rejected** — register, then reject instead of approve. Rejecting needs an `approval_remark_id`
(a real row's `id`) — look one up first:

```bash
REMARK_ID=$(curl -s "$BASE_URL/api/v1/approvals/approval_remarks" \
  -H "Authorization: $OFFICER_TOKEN" | jq -r '.data[0].id')

curl -s -X POST "$BASE_URL/api/v1/approvals/fishermen/$FISHERMAN_ID/reject" \
  -H "Authorization: $OFFICER_TOKEN" -H "Content-Type: application/json" \
  -d "{\"approval_remark_id\": \"$REMARK_ID\"}" | jq .

curl -s -X POST "$BASE_URL/api/v1/auth/brunei_id" \
  -H "Content-Type: application/json" -d '{"ic_number": "01-800201"}' | jq .
```

Returns 200, `data.status: "rejected"`, `data.rejection_reason` present, no `access_token`.

**Not found** — any `ic_number` nobody registered:

```bash
curl -s -X POST "$BASE_URL/api/v1/auth/brunei_id" \
  -H "Content-Type: application/json" -d '{"ic_number": "00-000000"}'
```

Returns **404 Not Found**, `{"status": "fail", "message": "Resource not found."}`.

---

## Testing via Postman instead

`postman/DoFi-Backend.postman_collection.json`'s **Auth** folder has this entire Fisherman flow
pre-built and runnable end-to-end: `Setup - Register a Fisherman (for BruneiID Login demo)` →
`Setup - Approve the Fisherman (for BruneiID Login demo)` → `BruneiID Login - Active`, plus
standalone `Setup - Register a Fisherman (Pending, ...)` → `BruneiID Login - Pending` and
`BruneiID Login - Not Found (404)` requests. Run the **Auth** folder (or the whole collection) with
the `DoFi Backend - Local` or `DoFi Backend - Staging` environment selected — no manual token
copying needed, each request chains off the last via collection variables
(`brunei_demo_fisherman_id`, `jwt_token`, etc.).

There's no pre-built Jetty Manager equivalent in the collection today — use Part B above, or copy
the Fisherman requests and swap the endpoint/body per the registration-flow.md section 1 shape.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `brunei_id` login returns 404 for an `ic_number` you just registered | Typo, or registered on a different environment than you're testing against | Re-check `BASE_URL` and the exact `ic_number` string (must match byte-for-byte, no normalization happens) |
| `brunei_id` login returns 200 but no `access_token`, and you expected one | User is not `active` yet | Approve it first via `POST /api/v1/approvals/{fishermen,jetty_managers}/:id/approve` as an officer |
| Approve/reject call returns 401/403 | Missing or expired `OFFICER_TOKEN`, or the officer's role lacks the `*_approvals.approve` permission | Re-run the officer sign-in step; confirm the role via `GET /api/v1/roles` |
| Officer sign-in itself fails with "Invalid username or password" | Using `email` instead of `username`, or wrong casing expectations | Officers authenticate by `username`, not `email` (see registration-flow.md's "DoFi Officer/Administrator login" note). Username is stored lowercase regardless of how it was typed/seeded. |
| Same `ic_number` reused across test runs hits a uniqueness error on register | A prior test run already created that IC | Pick a fresh `ic_number`, or look up/reuse the existing record instead of re-registering |
| Register call 500s with `PG::UniqueViolation` on `index_users_on_email` | Known pre-existing gap: Devise's email uniqueness check uses `allow_blank: true`, so it never catches a second blank-email row at the validation layer — the DB's plain unique index does, as a raw 500 instead of a 422. Registration always submits a blank email (Fisherman/Jetty Manager have none), so this fires as soon as **any** blank-email row already exists | Not something to work around per-request — find and clear the stale blank-email row(s) first (`User.where(email: [nil, ""])`), or fix the underlying validation (out of scope for this doc) |
