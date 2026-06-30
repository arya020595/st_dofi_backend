# Registration Flow

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
  → User created (status: active, role: Jetty Manager)
  → FE receives user record + JWT → redirect to dashboard
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
    "status":            "active",
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
      "reference_id": "ROLE-002",
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
| `role` | `Role` where `reference_id = "ROLE-002"` (Jetty Manager) |
| `status` | `active` (AASM default — no approval step needed) |
| `brunei_id_verified_at` | `Time.current` |
| `password` | `SecureRandom.base64(24)` (never exposed) |

---

## 2. Fisherman Registration

Fisherman registration has two sub-flows driven by `registration_type`:

| Registration Type | Company Profile required? | Fields |
|---|---|---|
| `"Commercial"` | Yes — IC must match a `CompanyProfile` | name, ic_number, registration_type, designation |
| `"Small-Scale (Company)"` | Yes — IC must match a `CompanyProfile` | name, ic_number, registration_type, designation |
| `"Small - Scale (Full-Time)"` | No | name, ic_number, registration_type |

All fishermen are created with `status: pending` and require officer approval before they can log in.

### Flow

```
FE: User scans QR code
  → BruneiID callback returns ic_number + name (pre-filled on form)
  → User selects Registration Type

  [Commercial / Small-Scale (Company)]
    → FE GET /api/v1/registrations/fisherman/company_profile?ic_no=<ic_number>
      → Found: pre-fill Company Name, ROCBN No. on form (read-only)
      → Not Found: show dashes, block Proceed to Register button
    → User selects Owner or Admin (designation)
    → FE POST /api/v1/registrations/fisherman
    → User created (status: pending, linked to CompanyProfile)
    → FE shows "Registration Status: Pending" screen

  [Small - Scale (Full-Time)]
    → No lookup needed
    → FE POST /api/v1/registrations/fisherman
    → User created (status: pending, no company link)
    → FE shows "Registration Status: Pending" screen
```

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
    "ic_no":             "01-192839"
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

Returns 404 also when the `CompanyProfile` exists but has been soft-deleted (`discarded_at` is set).

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
      "rocbn_no":          "RC20390923",
      "full_name":         "Muhammad Shahrizan Bin Haji Said",
      "ic_no":             "01-192839"
    },
    "role": {
      "reference_id": "ROLE-003",
      "name":         "Fisherman"
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
| `role` | `Role` where `reference_id = "ROLE-003"` (Fisherman) |
| `status` | `pending` (must be approved by an officer) |
| `company_profile` | Matched `CompanyProfile` (by `ic_no`) for Commercial/Company types; `nil` for Full-Time |
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

> Jetty Manager users are created directly as `active` — they skip the pending/approval step entirely.

---

## 4. What Is Not Built Yet

| Feature | Notes |
|---|---|
| Officer approve/reject endpoint | Moves a fisherman from `pending` → `active` or `rejected`, sets `rejection_reason` on `rejected` |
| Admin create CompanyProfile endpoint | Officers pre-create `CompanyProfile` records before fishermen can self-register; no controller exists yet |
| Registration status check endpoint | ✅ Built — `GET /api/v1/registrations/status?ic_number=...` |
| Login after registration | Fishermen with `pending`/`rejected` status cannot log in yet; the sessions endpoint should gate on `active` status (not implemented) |
