# Registration And BruneiID Flow

For the business-level picture, see [`business-flow.md`](business-flow.md). This doc covers the
request/response contracts for Jetty Manager registration, Fisherman provisioning, and BruneiID
login.

## 1. Business Split

Fisherman and Jetty Manager onboarding intentionally differ.

| Audience | Missing user after BruneiID lookup | Lifecycle authority |
|---|---|---|
| Fisherman | Stop; no registration | `users.fisherman_status` |
| Jetty Manager | Open registration | `users.status` |

Shared infrastructure:

- BruneiID callback/mock verification.
- IC normalization.
- Global kept-user IC uniqueness through `normalized_ic_number`.

Separate lifecycle:

- Fisherman uses `Fisherman::Authenticate`, `Fisherman::ProvisionUser`, and
  `Fisherman::ClaimAccount`.
- Jetty Manager keeps `Users::RegisterJettyManager` and existing approval/login behavior.

## 2. Registration Status Check

```
GET /api/v1/registrations/status?ic_number=01-1234567
```

This endpoint performs a normalized IC lookup against kept users.

| Response | Meaning |
|---|---|
| 200 + `status: "active"` | Existing active Jetty/global status user |
| 200 + `status: "pending"` | Existing pending Jetty Manager |
| 200 + `status: "rejected"` | Existing rejected Jetty Manager |
| 200 + `status: "pending_approval"` | Existing Fisherman awaiting DoFI approval |
| 200 + `status: "claimable"` | Existing Fisherman approved/provisioned but not claimed |
| 404 | No kept user with that normalized IC |

Fisherman UX must not open registration when no eligible Fisherman account is resolved for the
verified IC. Jetty Manager UX may open Jetty Manager registration only when Jetty-scoped lookup
does not find a user with the system Jetty Manager role.

**Found - 200 OK**

```json
{
  "status": "success",
  "data": {
    "id": "uuid",
    "name": "Amiirul Azri Mizamuddin",
    "status": "pending",
    "fisherman_status": null,
    "unit": "Docks",
    "position": "Jetty Supervisor",
    "company_profile": null,
    "role": { "name": "Jetty Manager", "kind": "Jetty Manager" }
  }
}
```

**Not Found - 404 Not Found**

```json
{ "status": "fail", "message": "Resource not found." }
```

## 3. Jetty Manager Registration

Jetty Manager registration remains public.

```
POST /api/v1/registrations/jetty_manager
```

**Request body**

```json
{
  "user": {
    "name": "Amiirul Azri Mizamuddin",
    "ic_number": "01-1234567",
    "unit": "Docks",
    "position": "Jetty Supervisor",
    "contact_no": "71111111"
  }
}
```

**Success - 201 Created**

```json
{
  "status": "success",
  "data": {
    "id": "uuid",
    "name": "Amiirul Azri Mizamuddin",
    "ic_number": "01-1234567",
    "normalized_ic_number": "011234567",
    "status": "pending",
    "fisherman_status": null,
    "unit": "Docks",
    "position": "Jetty Supervisor",
    "contact_no": "71111111",
    "role": { "kind": "Jetty Manager", "name": "Jetty Manager" },
    "company_profile": null
  }
}
```

Service behavior:

| Field | Value |
|---|---|
| `role` | `Role.kind = "Jetty Manager"` |
| `status` | `pending` |
| `fisherman_status` | `nil` |
| `normalized_ic_number` | Written from `ic_number` |
| `brunei_id_verified_at` | Set at registration time |
| `password` | Random server-generated value |

## 4. Fisherman Provisioning

There is no Fisherman self-registration in Flow B.

Retired runtime paths/classes:

- `POST /api/v1/registrations/fisherman`
- `GET /api/v1/registrations/fisherman/company_profile`
- `Users::RegisterFisherman`

Fisherman users must already exist before QR login. There are two provisioning sources:

| Source | Caller | Initial `fisherman_status` | Approval |
|---|---|---|---|
| `dofi_company_profile` | DoFI Company Profiling | `pending_approval` | Required |
| `fisherman_owner` | Fisherman Owner User Management | `claimable` | Not required |

### Source A - DoFI Company Profiling

```
POST /api/v1/admin/company_profiles
```

Company Profile creation creates the profile, contact rows, and provisioned Owner/Admin Fisherman
users in one transaction. Owner/Admin roles are derived from contact designation; callers do not
submit a role.

**Request body**

```json
{
  "company_profile": {
    "registration_type": "Commercial",
    "company_name": "Azri Fish Sdn Bhd",
    "company_address": "Spg 10, Pantai Serasa, Mukim Serasa",
    "rocbn_no": "RC20390923",
    "contact_no": "71111111",
    "district": "Brunei - Muara",
    "mukim": "Serasa",
    "village": "Kapok",
    "fisherman_card_no": "R-2026-012563",
    "issue_date": "2026-01-01",
    "license_expiry_date": "2026-12-31",
    "worker_quota": 34,
    "owner": {
      "full_name": "Muhammad Shahrizan Bin Haji Said",
      "gender": "Male",
      "ic_no": "01-192839",
      "ic_colour": "Yellow"
    },
    "admin": {
      "full_name": "Seruddin Bin Haji Abdullah",
      "gender": "Male",
      "ic_no": "01-192840",
      "ic_colour": "Yellow"
    }
  }
}
```

**Success - 201 Created**

```json
{
  "status": "success",
  "data": {
    "company_profile": { "id": "uuid", "registration_type": "Commercial" },
    "owner_profile": { "id": "uuid", "designation": "Owner", "ic_no": "01-192839" },
    "admin_profile": { "id": "uuid", "designation": "Admin", "ic_no": "01-192840" },
    "owner_user": {
      "id": "uuid",
      "name": "Muhammad Shahrizan Bin Haji Said",
      "status": "active",
      "fisherman_status": "pending_approval",
      "provisioning_source": "dofi_company_profile",
      "role": { "name": "Owner", "platform_scope": "fisherman" }
    },
    "admin_user": {
      "id": "uuid",
      "name": "Seruddin Bin Haji Abdullah",
      "status": "active",
      "fisherman_status": "pending_approval",
      "provisioning_source": "dofi_company_profile",
      "role": { "name": "Admin", "platform_scope": "fisherman" }
    }
  }
}
```

`owner` is required; `admin` is optional. For Small - Scale (Full-Time) / Part-Time, submit only
the Owner contact and omit company-shape fields.

### Source B - Fisherman User Management

```
POST /api/v1/fisherman/users
```

Creates a teammate under the signed-in Fisherman Owner's own company. `company_profile_id` is
server-derived from `current_user`; it is never accepted from the request body.

**Request body**

```json
{
  "user": {
    "name": "Postman Test Teammate",
    "ic_number": "01-880001",
    "registration_type": "Commercial",
    "role_id": "custom-role-uuid"
  }
}
```

**Success - 201 Created**

```json
{
  "status": "success",
  "data": {
    "id": "uuid",
    "name": "Postman Test Teammate",
    "status": "active",
    "fisherman_status": "claimable",
    "provisioning_source": "fisherman_owner",
    "role": { "name": "Deck Crew", "platform_scope": "fisherman" }
  }
}
```

Source B role validation:

- `role_id` is required.
- Role must belong to the actor's company.
- Role must have `platform_scope = "fisherman"`.
- System Owner/Admin role assignment is blocked. Source B is for custom-role teammates only.

## 5. Fisherman Approval

DoFI-created Fisherman Owner/Admin users enter the approval queue with:

```text
fisherman_status = pending_approval
```

Approve:

```
POST /api/v1/admin/approvals/fishermen/:id/approve
```

Optional body:

```json
{ "reason": "Identity verified by DoFI profiling review" }
```

Result:

```text
pending_approval -> claimable
```

Reject:

```
POST /api/v1/admin/approvals/fishermen/:id/reject
```

Body:

```json
{
  "approval_remark_id": "uuid",
  "reason": "IC did not match supporting documents"
}
```

Result:

```text
pending_approval -> revoked
```

Approval and rejection lock the user row, recheck FINS target eligibility inside the lock,
transition `fisherman_status`, and write audit actor/comment. Rejection writes rejection semantics
only; explicit revoke is a separate FINS action that sets revocation metadata.

## 6. Mock BruneiID Login

```
POST /api/v1/auth/brunei_id
```

Request:

```json
{ "ic_number": "01-192839" }
```

This legacy/mock endpoint preserves old behavior when no `audience` is provided. When `audience`
is provided, lookup is audience-scoped: `fisherman` resolves Fisherman accounts through
`Fisherman::Authenticate`, while `jetty_manager` resolves only a user with the system Jetty Manager
role.

**Active response - 200 OK**

```json
{
  "status": "success",
  "data": {
    "access_token": "<jwt>",
    "user": {
      "id": "uuid",
      "status": "active",
      "fisherman_status": "active"
    }
  }
}
```

**Pending/revoked response - 200 OK, no token**

```json
{
  "status": "success",
  "data": {
    "id": "uuid",
    "status": "active",
    "fisherman_status": "pending_approval"
  }
}
```

**Not found - 404 Not Found**

```json
{ "status": "fail", "message": "Account not found." }
```

## 7. BruneiID OIDC Callback

```
POST /api/v1/auth/brunei_id/callback
```

Request:

```json
{
  "code": "oidc-code",
  "code_verifier": "pkce-verifier",
  "redirect_uri": "https://frontend.example/callback",
  "nonce": "expected-nonce",
  "audience": "fisherman"
}
```

Supported audiences:

- `fisherman`
- `jetty_manager`

### Fisherman callback behavior

| `fisherman_status` | Response behavior |
|---|---|
| no Fisherman user | 404, `code: "fisherman_account_not_provisioned"` |
| `pending_approval` | 200 status payload, no token |
| `claimable` | Claims account, returns dashboard token |
| `active` | Returns dashboard token |
| `suspended` / `revoked` | 422 inactive registration response |

Unknown Fisherman IC:

```json
{
  "status": "fail",
  "message": "No Fisherman account has been provisioned for this IC number. Please contact DoFI or your company administrator.",
  "code": "fisherman_account_not_provisioned"
}
```

### Jetty Manager callback behavior

| User lookup | Response behavior |
|---|---|
| missing Jetty Manager user | 200, `next_action: "registration"` |
| existing pending/rejected user | 200 registration status payload, no token |
| existing active user | 200 dashboard payload with token |

Missing Jetty Manager user:

```json
{
  "status": "success",
  "data": {
    "next_action": "registration",
    "ic_number": "01-1234567",
    "registration_status": "not_found"
  }
}
```

The Jetty missing-user path does not weaken global IC uniqueness. Registration still fails if the
normalized IC is already owned by any kept user in another audience.

## 8. Identity And Uniqueness

`normalized_ic_number` is globally unique across all kept users. It is not scoped by Fisherman
company, platform, or role. This means a Fisherman and Jetty Manager cannot share the same
normalized IC.

The DB unique index is kept-row-aware:

```sql
UNIQUE(normalized_ic_number)
WHERE normalized_ic_number IS NOT NULL
AND discarded_at IS NULL
```

Application services still check availability first, but the database is the final authority.
Provisioning catches `ActiveRecord::RecordNotUnique`, rechecks the IC, and returns the
deterministic domain conflict symbol instead of leaking a database exception.

## 9. Owner/Admin User Management Rules

Fisherman User Management may manage custom-role users only. System-managed Owner/Admin users are
created from DoFI Company Profiling, governed through FINS Approval, and are not assignable from
Fisherman User Management.

It must not:

- Create a user with Owner role.
- Create a user with Admin role.
- Assign Owner role to another user.
- Assign Admin role to another user.
- Change an Owner user's role.
- Change an Admin user into a Fisherman-side system role.
- Delete/discard an Owner user.
- Suspend/revoke/disable an Owner user.
- Change the actor's own Owner role.
- Create a second Owner assignment.

Owner access governance is a DoFI Profiling responsibility.

## 10. DoFI Officer Login

Officers log in separately:

```
POST /api/v1/auth/sign_in
```

Request:

```json
{
  "user": {
    "username": "mprt/dof-001",
    "password": "ChangeMe123!"
  }
}
```

This is real username/password authentication through Devise/JWT and is unrelated to BruneiID.
