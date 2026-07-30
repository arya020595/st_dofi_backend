# Registration Flow

For the business-level picture (actors, roles, lifecycles, and the reasoning behind key decisions), see [`business-flow.md`](business-flow.md). This doc covers the endpoint request/response contracts.

All registration endpoints are **public** (no `Authorization` header required). Authentication happens via BruneiID/QR scan on the frontend before the register form is shown — the backend receives the result of that verification, not a token.

Passwords are never set by the user. A cryptographically random password is generated server-side on registration; the user always re-authenticates via BruneiID.

---

## 0. Registration Status Check

Before showing the register form or redirecting to login, the FE checks whether the user's IC number already has an account. This is shared by both the Jetty Manager and Fisherman flows.

```
GET /api/v1/registrations/status?ic_number=01-1234567
```

| Response | Meaning | FE action |
|---|---|---|
| 200 + `status: "active"` | Already registered and approved | Redirect to login |
| 200 + `status: "pending"` | Registered but awaiting officer approval | Show "Registration Status: Pending" screen |
| 200 + `status: "rejected"` | Registered but rejected by officer | Show "Registration Status: Rejected" screen with `rejection_reason` |
| 404 | No account found for this IC | Show registration form |

**Found — 200 OK**

```json
{
  "status": "success",
  "data": {
    "id":     "uuid",
    "name":   "Amiirul Azri Mizamuddin",
    "status": "pending",
    "unit":   "Docks",
    "position": "Jetty Supervisor",
    "company_profile": null,
    "role": { "name": "Jetty Manager" }
  }
}
```

**Not Found — 404 Not Found**

```json
{
  "status": "fail",
  "message": "Resource not found."
}
```

---

## 1. Jetty Manager Registration

### Flow

```
FE: User scans QR code
  → BruneiID callback returns ic_number + name (pre-filled on form)
  → User fills in Unit, Position, Contact No.
  → FE POST /api/v1/registrations/jetty_manager
  → User created (status: pending, role: Jetty Manager)
  → FE shows "Registration Status: Pending" screen
```

### Endpoint

```
POST /api/v1/registrations/jetty_manager
```

**Request body**

```json
{
  "user": {
    "name":       "Amiirul Azri Mizamuddin",
    "ic_number":  "01-1234567",
    "unit":       "Docks",
    "position":   "Jetty Supervisor",
    "contact_no": "71111111"
  }
}
```

All five fields are required.

**Success — 201 Created**

```json
{
  "status": "success",
  "data": {
    "id":                "uuid",
    "name":              "Amiirul Azri Mizamuddin",
    "email":             null,
    "employee_id":       null,
    "status":            "pending",
    "preferred_locale":  "en",
    "unit":              "Docks",
    "position":          "Jetty Supervisor",
    "contact_no":        "71111111",
    "designation":       null,
    "registration_type": null,
    "created_at":        "...",
    "updated_at":        "...",
    "role": {
      "id":           "uuid",
      "kind":         "Jetty Manager",
      "name":         "Jetty Manager",
      "description":  "Port-level authority: ...",
      "permissions":  [ ... ]
    },
    "company_profile": null
  }
}
```

**Failure — 422 Unprocessable Content**

```json
{
  "status": "fail",
  "errors": ["IC number has already been taken", "Unit can't be blank"]
}
```

### What the service does (`Users::RegisterJettyManager`)

| Field | Value |
|---|---|
| `role` | `Role` where `kind = "Jetty Manager"` |
| `status` | `pending` (must be approved by an officer) |
| `brunei_id_verified_at` | `Time.current` |
| `password` | `SecureRandom.base64(24)` (never exposed) |

---

## 2. Fisherman Registration

Fisherman registration has two sub-flows driven by `registration_type`:

| Registration Type | Company Profile required? | Fields |
|---|---|---|
| `"Commercial"` | Yes — IC must match a `CompanyProfileContact` | name, ic_number, registration_type, designation |
| `"Small-Scale (Company)"` | Yes — IC must match a `CompanyProfileContact` | name, ic_number, registration_type, designation |
| `"Small - Scale (Full-Time)"` | Yes — IC must match a `CompanyProfileContact` on an individual-shaped `CompanyProfile` (see §5) | name, ic_number, registration_type |

Every type is matched the same way — by `ic_number` against a `CompanyProfileContact` an officer
pre-profiled. Full-Time has no separate "no company" path: it uses the same
`POST /api/v1/admin/company_profiles` flow, just profiled with only an Owner contact (the fisherman
themselves) and none of the company-shape fields (`company_name`, `worker_quota`, ...), since
`CompanyProfile#individual?` makes those optional for this registration_type.

All fishermen are created with `status: pending` and require officer approval before they can log in.

### Flow

```
FE: User scans QR code
  → BruneiID callback returns ic_number + name (pre-filled on form)
  → User selects Registration Type

  [Commercial / Small-Scale (Company) / Small - Scale (Full-Time)]
    → FE GET /api/v1/registrations/fisherman/company_profile?ic_no=<ic_number>
      → Found: pre-fill Company Name, ROCBN No. on form (read-only; Full-Time has no
        company_name to show, just confirms the IC is pre-profiled)
      → Not Found: show dashes, block Proceed to Register button
    → Designation (Owner/Admin) is pre-filled from the lookup — not a manual choice
    → FE POST /api/v1/registrations/fisherman
    → User created (status: pending, linked to CompanyProfile)
    → FE shows "Registration Status: Pending" screen
```

Every registration type requires the IC to already be profiled (§5) before this step — there is no
"register first, get profiled later" path for any type, including Full-Time.

---

### 2a. Company Profile IC Lookup

Used by the FE to pre-fill company fields and gate the Register button.

```
GET /api/v1/registrations/fisherman/company_profile?ic_no=01-192839
```

**Found — 200 OK**

```json
{
  "status": "success",
  "data": {
    "id":                "uuid",
    "registration_type": "Commercial",
    "company_name":      "Azri Fish Sdn Bhd",
    "rocbn_no":          "RC20390923",
    "full_name":         "Muhammad Shahrizan Bin Haji Said",
    "ic_no":             "01-192839",
    "designation":       "Owner"
  }
}
```

**Not Found — 404 Not Found**

```json
{
  "status": "fail",
  "message": "Resource not found."
}
```

Returns 404 also when the `CompanyProfileContact` exists but has been soft-deleted (`discarded_at` is
set).

---

### 2b. Fisherman Register

```
POST /api/v1/registrations/fisherman
```

**Request body — Commercial / Small-Scale (Company)**

```json
{
  "user": {
    "name":              "Muhammad Shahrizan Bin Haji Said",
    "ic_number":         "01-192839",
    "registration_type": "Commercial",
    "designation":       "Owner"
  }
}
```

**Request body — Small - Scale (Full-Time)**

```json
{
  "user": {
    "name":              "Muhammad Shahrizan Bin Haji Said",
    "ic_number":         "01-192839",
    "registration_type": "Small - Scale (Full-Time)"
  }
}
```

Valid values for `registration_type`: `"Commercial"`, `"Small-Scale (Company)"`, `"Small - Scale (Full-Time)"`.

**Success — 201 Created**

```json
{
  "status": "success",
  "data": {
    "id":                "uuid",
    "name":              "Muhammad Shahrizan Bin Haji Said",
    "status":            "pending",
    "registration_type": "Commercial",
    "designation":       "Owner",
    "company_profile": {
      "id":                "uuid",
      "registration_type": "Commercial",
      "company_name":      "Azri Fish Sdn Bhd",
      "rocbn_no":          "RC20390923"
    },
    "company_profile_contact": {
      "id":                 "uuid",
      "full_name":          "Muhammad Shahrizan Bin Haji Said",
      "ic_no":              "01-192839",
      "ic_colour":          "Yellow",
      "gender":             "Male",
      "designation":        "Owner",
      "company_profile_id": "uuid"
    },
    "role": {
      "kind": "Fisherman",
      "name": "Fisherman"
    }
  }
}
```

**Failure — 422 Unprocessable Content** (validation errors)

```json
{
  "status": "fail",
  "errors": ["Registration type is not included in the list"]
}
```

**Failure — 404 Not Found** (Commercial/Company type, IC not matched to any active CompanyProfile)

```json
{
  "status": "fail",
  "message": "Resource not found."
}
```

### What the service does (`Users::RegisterFisherman`)

| Field | Value |
|---|---|
| `role` | `Role` where `kind = "Fisherman"` |
| `status` | `pending` (must be approved by an officer) |
| `company_profile` | The matched `CompanyProfileContact`'s `company_profile` — required for every registration_type, including Full-Time |
| `designation` | Derived server-side from the matched `CompanyProfileContact`'s `designation` — any client-submitted value is ignored, for every type |
| `brunei_id_verified_at` | `Time.current` |
| `password` | `SecureRandom.base64(24)` (never exposed) |

---

## 3. User Status State Machine (AASM)

```
           ┌─────────────────────────────────────┐
           │                                     │
           ▼                                     │
        pending ──approve!──► active ◄──reactivate!──┐
           │                   │  │                  │
        reject!            deactivate! suspend!      │
           │                   │  │                  │
           ▼                   ▼  ▼                  │
        rejected          inactive  suspended ────────┘
                              │         │
                         suspend!  deactivate!
                              │         │
                              ▼         ▼
                          suspended   inactive
```

| Event | From | To | Who triggers it |
|---|---|---|---|
| `approve!` | pending | active | Officer (future endpoint) |
| `reject!` | pending | rejected | Officer (future endpoint) |
| `deactivate!` | active, suspended | inactive | Admin |
| `suspend!` | active, inactive | suspended | Admin |
| `reactivate!` | inactive, suspended | active | Admin |

---

## 4. What Is Not Built Yet

| Feature | Notes |
|---|---|
| Officer approve/reject endpoint | ✅ Built — `POST /api/v1/admin/approvals/fishermen/:id/approve`\|`reject` and `POST /api/v1/admin/approvals/jetty_managers/:id/approve`\|`reject`. Moves a Fisherman or Jetty Manager from `pending` → `active` or `rejected`, sets `rejection_reason` on `rejected` |
| Admin create CompanyProfile endpoint | ✅ Built — `POST /api/v1/admin/company_profiles` (see "5. Officer Profiling" below). Officers pre-create `CompanyProfile` records (Owner and optionally Admin) before fishermen self-register |
| Registration status check endpoint | ✅ Built — `GET /api/v1/registrations/status?ic_number=...` |
| Login after registration | ✅ Built — `POST /api/v1/auth/brunei_id` (see "6. Mock BruneiID Login" below). Gates on `active` status; `pending`/`rejected` get the same status payload as the registration-status check instead of a token |

---

## 5. Officer Profiling (pre-creating a CompanyProfile)

Unlike everything above, this endpoint is **authenticated** (`profiling.*` permission required — DoFi Officer has it via full access, and Fisherman also has `profiling.create`/`profiling.update`). It lets an officer (or, once already registered/active, a fisherman for their own profile) pre-create the `CompanyProfile` record(s) a fisherman will later match against by IC number during self-registration (section 2a) — this applies to **every** registration type, including Small - Scale (Full-Time).

`CompanyProfile` and its sub-resources are dual-mounted: the same controllers are reachable at
`/api/v1/admin/company_profiles/...` (DoFi Officer, Jetty Manager) and
`/api/v1/fisherman/company_profiles/...` (Fisherman, scoped to their own company via
`CompanyProfilePolicy::Scope`). Every path below shows the `admin/` prefix since officer profiling is
the primary flow this section documents — swap in `fisherman/` for the self-service case.

For Small - Scale (Full-Time), profile only an Owner (the fisherman themselves) and omit every
company-shape field — `CompanyProfile#individual?` (true when `registration_type` is Full-Time)
makes `company_name`, `company_address`, `rocbn_no`, `contact_no`, `district`, `mukim`, `village`,
`fisherman_card_no`, `issue_date`, `license_expiry_date`, and `worker_quota` all optional for that
type only:

```json
{
  "company_profile": {
    "registration_type": "Small - Scale (Full-Time)",
    "owner": { "full_name": "Solo Fisherman", "gender": "Male", "ic_no": "01-999001", "ic_colour": "Yellow" }
  }
}
```

```
POST /api/v1/admin/company_profiles
```

**Request body**

```json
{
  "company_profile": {
    "registration_type":   "Small-Scale (Company)",
    "company_name":        "Azri Fish Sdn Bhd",
    "company_address":     "Spg 10, Pantai Serasa, Mukim Serasa",
    "rocbn_no":            "RC20390923",
    "contact_no":          "71111111",
    "district":            "Brunei - Muara",
    "mukim":               "Serasa",
    "village":             "Kapok",
    "fisherman_card_no":   "R-2026-012563",
    "issue_date":          "2026-01-01",
    "license_expiry_date": "2026-12-31",
    "worker_quota":        34,
    "owner": { "full_name": "Abdul Rahman Bin Matussin", "gender": "Male", "ic_no": "01-102934", "ic_colour": "Yellow" },
    "admin": { "full_name": "Seruddin Bin Haji Abdullah", "gender": "Male", "ic_no": "01-129303", "ic_colour": "Yellow" }
  }
}
```

`owner` is required; `admin` is optional — omit it (or submit it empty) to profile only an Owner. All other fields are required except `rocbn_no`.

### What the service does (`CompanyProfiles::Create`)

`CompanyProfile` is one row per **company**; the person-level fields (`full_name`, `ic_no`,
`ic_colour`, `gender`, `designation`) live on a separate `CompanyProfileContact` row,
`belongs_to :company_profile`. One `POST` creates **one `CompanyProfile`** plus a required Owner
`CompanyProfileContact` and an optional Admin `CompanyProfileContact`, all in one transaction:

| Field | Value |
|---|---|
| `dofi_registration_no` | Auto-generated on the `CompanyProfile` — a `SecureRandom.uuid`, not a human-readable sequence. It's an opaque internal identifier, not a displayed business code. |
| `designation` | `"Owner"` / `"Admin"` per contact |

If any row fails validation, the whole submission rolls back — no partial (company created with no
Owner, or Owner-only-when-Admin-was-requested) state is left behind.

**Success — 201 Created**

```json
{
  "status": "success",
  "data": {
    "company_profile": { "id": "uuid", "dofi_registration_no": "a1b2c3d4-...", "company_name": "...", "...": "..." },
    "owner_profile": { "id": "uuid", "designation": "Owner", "company_profile_id": "uuid", "...": "..." },
    "admin_profile": { "id": "uuid", "designation": "Admin", "company_profile_id": "uuid", "...": "..." }
  }
}
```

`admin_profile` is `null` when no `admin` was submitted.

Also supports standard `GET /api/v1/admin/company_profiles` (list, searchable via `q[company_name_cont]`/`q[rocbn_no_cont]` — this is how the FE's "Select & Search Company" picks an existing company), `GET /api/v1/admin/company_profiles/:id`, `PATCH /api/v1/admin/company_profiles/:id` (company-level fields only — no `owner`/`admin`), and `DELETE /api/v1/admin/company_profiles/:id` (soft-deletes the company **and** its contacts together).

### Adding a contact to an existing company (`CompanyProfileContacts::Create`)

To profile a second person against a company that already exists (e.g. adding an Admin to a company
profiled last week), the FE's "Select & Search Company" step finds the existing `CompanyProfile`, then
calls the nested contacts endpoint instead of resubmitting `create` — no company fields, no risk of
duplicating the Owner:

```
POST /api/v1/admin/company_profiles/:company_profile_id/contacts
```

```json
{ "contact": { "full_name": "Seruddin Bin Haji Abdullah", "gender": "Male", "ic_no": "01-129303",
               "ic_colour": "Yellow", "designation": "Admin" } }
```

Also supports `PATCH .../contacts/:id` and `DELETE .../contacts/:id` (removes just that person, leaving the company and any other contacts untouched).

---

## 6. Mock BruneiID Login

Fishermen and Jetty Managers have no username/password login — after registration, subsequent "log in" is a BruneiID QR re-scan on the frontend. Since there's no real BruneiID integration yet, this endpoint is a **mock** stand-in: it trusts the FE-supplied `ic_number` as already BruneiID-verified, the same trust boundary registration itself already relies on (`brunei_id_verified_at` is set unconditionally at registration time, with no real verification call either). It is **public** (no `Authorization` header required).

```
POST /api/v1/auth/brunei_id
```

**Request body**

```json
{ "ic_number": "01-192839" }
```

**Found, `active` — 200 OK** (same shape as the officer `/api/v1/auth/sign_in` response)

```json
{
  "status": "success",
  "data": {
    "access_token": "<jwt>",
    "user": { "id": "uuid", "name": "...", "status": "active", "...": "..." }
  }
}
```

**Found, `pending` or `rejected` — 200 OK** (same shape as `GET /api/v1/registrations/status` — no `access_token`, so the FE reuses its existing pending/rejected status screens rather than a new error shape)

```json
{
  "status": "success",
  "data": { "id": "uuid", "name": "...", "status": "pending", "...": "..." }
}
```

**Not found — 404 Not Found**

```json
{ "status": "fail", "message": "Resource not found." }
```

This is explicitly a mock — see `app/services/brunei_id/client.rb` for the swap-in point for a real BruneiID integration later (the `faraday`/`jwt` gems and `BRUNEIID_*` env vars are already reserved for it, unused today).

For a step-by-step curl/Postman walkthrough of testing Fisherman/Jetty Manager login end-to-end (register → approve → mock login → authenticated request, plus pending/rejected/not-found), see [`testing-mock-brunei-id-login.md`](testing-mock-brunei-id-login.md).

### DoFi Officer/Administrator login (for contrast)

Officers log in separately via `POST /api/v1/auth/sign_in` with `{ "user": { "username": "...", "password": "..." } }` — a real username+password check against this app's own `encrypted_password` (not BruneiID, not real Active Directory/SSO — `username` is just an AD-style identifier the app owns and validates itself). This endpoint is unchanged in shape; only the login field switched from `email` to `username`.
