# Provisioning And BruneiID Flow

For the business-level picture, see [`business-flow.md`](business-flow.md). This doc covers the
request/response contracts for Jetty Manager creation, Fisherman provisioning, and BruneiID login.

## 1. Business Split

Neither external audience self-registers or waits for approval: a DoFi Officer (or, for Fisherman
teammates, the company's Owner) provisions every account before its first BruneiID scan.

| Audience | Provisioned by | Initial state | Missing user after BruneiID lookup | Lifecycle authority |
|---|---|---|---|---|
| Fisherman | Company Profiling / Fisherman User Management | `fisherman_status: claimable` | Stop; `fisherman_account_not_provisioned` | `users.fisherman_status` |
| Jetty Manager | User Management → External Users | `status: active` | Stop; `jetty_manager_account_not_provisioned` | `users.status` |

Shared infrastructure:

- BruneiID OIDC callback verification.
- IC normalization.
- Global kept-user IC uniqueness through `normalized_ic_number`.

Separate lifecycle:

- Fisherman uses `Fisherman::ProvisionUser`, `Fisherman::Authenticate`, and `Fisherman::ClaimAccount`.
- Jetty Manager uses `Users::CreateJettyManager`, then `Users::DeactivateRegistration`/
  `Users::ReactivateRegistration`.

## 2. Jetty Manager Creation

```
POST /api/v1/admin/external_users/jetty_managers
```

Officer-only (`external_users.create`). The officer is the vetting step, so the account starts
`active` and the Jetty Manager can log in via BruneiID straight away.

**Request body**

```json
{
  "jetty_manager": {
    "name": "Amiirul Azri Mizamuddin",
    "ic_number": "01-1234567",
    "unit": "Docks",
    "position": "Jetty Supervisor",
    "contact_no": "71111111"
  }
}
```

`name`, `ic_number`, `unit`, and `position` are required; `contact_no` is optional. Any other key
(`role_id`, `status`, ...) is ignored.

**Success - 201 Created**

```json
{
  "status": "success",
  "data": {
    "id": "uuid",
    "name": "Amiirul Azri Mizamuddin",
    "ic_number": "01-1234567",
    "unit": "Docks",
    "position": "Jetty Supervisor",
    "contact_no": "71111111",
    "status": "active",
    "role": { "kind": "Jetty Manager", "name": "Jetty Manager" },
    "company_profile": null
  }
}
```

Service behavior:

| Field | Value |
|---|---|
| `role` | `Role.kind = "Jetty Manager"` |
| `status` | `active` |
| `created_by` | The creating officer |
| `normalized_ic_number` | Written from `ic_number`; must not belong to any other kept user |
| `password` | Random server-generated value, never surfaced |

Deactivate/reactivate go through `POST .../jetty_managers/:id/deactivate` and `.../reactivate`
(`external_users.deactivate`/`.reactivate`): `active -> inactive -> active`.

## 3. Fisherman Provisioning

There is no Fisherman self-registration. Fisherman users must already exist before QR login. There
are two provisioning sources, and both start claimable:

| Source | Caller | Initial `fisherman_status` |
|---|---|---|
| `dofi_company_profile` | DoFI Company Profiling | `claimable` |
| `fisherman_owner` | Fisherman Owner User Management | `claimable` |

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
      "fisherman_status": "claimable",
      "provisioning_source": "dofi_company_profile",
      "role": { "name": "Owner", "platform_scope": "fisherman" }
    },
    "admin_user": {
      "id": "uuid",
      "name": "Seruddin Bin Haji Abdullah",
      "status": "active",
      "fisherman_status": "claimable",
      "provisioning_source": "dofi_company_profile",
      "role": { "name": "Admin", "platform_scope": "fisherman" }
    }
  }
}
```

`owner` is required; `admin` is optional. For Small - Scale (Full-Time) / Part-Time, submit only
the Owner contact and omit company-shape fields.

Until the account is claimed, Company Profiling can still correct the contact's name/IC and the
provisioned user follows it. Once claimed, the identity is locked.

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

## 4. BruneiID OIDC Callback

Developers may enable the separate IC-only mock endpoint with `BRUNEIID_MOCK_ENABLED=true`
on local/staging. Production sets `false`; omitted/invalid values also hide the mock route.
See [testing BruneiID login](testing-brunei-id-login.md#mock-login-for-local-and-staging) for its
optional-audience compatibility contract. The real callback below always performs OIDC verification.

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
| `claimable` | Claims account, returns dashboard token |
| `active` | Returns dashboard token |
| `suspended` / `revoked` | 422 inactive registration response |

Unknown Fisherman IC:

```json
{
  "status": "fail",
  "message": "No Fisherman account has been provisioned for this IC number. Please contact DoFI or your company administrator.",
  "code": "fisherman_account_not_provisioned",
  "data": { "next_action": "registration_status", "ic_number": "01-1234567", "registration_status": "not_found" }
}
```

### Jetty Manager callback behavior

| User lookup | Response behavior |
|---|---|
| no Jetty Manager user | 404, `code: "jetty_manager_account_not_provisioned"` |
| `inactive` / `suspended` | 422 inactive registration response |
| `active` | 200 dashboard payload with token |

Unknown Jetty Manager IC:

```json
{
  "status": "fail",
  "message": "No Jetty Manager account has been provisioned for this IC number. Please contact DoFI.",
  "code": "jetty_manager_account_not_provisioned",
  "data": { "next_action": "registration_status", "ic_number": "01-1234567", "registration_status": "not_found" }
}
```

Both not-provisioned responses also carry the BruneiID profile fields (`full_name`,
`brunei_id_profile`, `brunei_id_token_metadata`) in `data`.

## 5. Identity And Uniqueness

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

## 6. Owner/Admin User Management Rules

Fisherman User Management may manage custom-role users only. System-managed Owner/Admin users are
created and governed from DoFI Company Profiling and are not assignable from Fisherman User
Management.

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

## 7. DoFI Officer Login

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
