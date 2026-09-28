# Testing Fisherman / Jetty Manager Login via Mock BruneiID

A practical walkthrough for exercising the audience-specific BruneiID login behavior locally or
on staging. For contracts, see [`registration-flow.md`](registration-flow.md).

## Why a mock

Fishermen and Jetty Managers authenticate with BruneiID QR re-scan, not username/password. There
is no real BruneiID integration or test credential set yet, so `POST /api/v1/auth/brunei_id`
stands in for verified BruneiID identity.

The onboarding models are intentionally different:

- Fisherman: provision-before-login; QR + BruneiID only claims/authenticates an existing user.
- Jetty Manager: created by a DoFi Officer (User Management → External Users) and active
  immediately; QR + BruneiID only authenticates an existing user.

Neither audience self-registers or waits for approval; an unknown IC is terminal for both.

DoFI Officer accounts are unaffected and keep using `POST /api/v1/auth/sign_in`.

## Prerequisites

```bash
BASE_URL=http://localhost:3000
```

Get an officer token first:

```bash
OFFICER_TOKEN=$(curl -s -D - -o /dev/null -X POST "$BASE_URL/api/v1/auth/sign_in" \
  -H "Content-Type: application/json" \
  -d '{"user": {"username": "mprt/dof-001", "password": "ChangeMe123!"}}' \
  | grep -i '^Authorization:' | tr -d '\r' | cut -d' ' -f2-)
```

## Part A - Fisherman Source A: DoFI Profile -> Claim

**1. Profile and provision the Fisherman Owner.**

```bash
curl -s -X POST "$BASE_URL/api/v1/admin/company_profiles" \
  -H "Authorization: $OFFICER_TOKEN" -H "Content-Type: application/json" \
  -d '{
    "company_profile": {
      "registration_type": "Small - Scale (Full-Time)",
      "owner": {
        "full_name": "Test Fisherman (Flow B)",
        "gender": "Male",
        "ic_no": "01-800201",
        "ic_colour": "Yellow"
      }
    }
  }' | jq .
```

The user exists immediately with `fisherman_status = "claimable"`.

**2. Claim/login with BruneiID.**

```bash
curl -s -D - -X POST "$BASE_URL/api/v1/auth/brunei_id" \
  -H "Content-Type: application/json" \
  -d '{"ic_number": "01-800201"}'
```

`Fisherman::ClaimAccount` locks the user, verifies the IC again, sets `claimed_at` and
`brunei_id_verified_at`, transitions `fisherman_status` to `active`, and returns a JWT.

## Part B - Fisherman Unknown IC Stops

```bash
curl -s -X POST "$BASE_URL/api/v1/auth/brunei_id" \
  -H "Content-Type: application/json" \
  -d '{"ic_number": "00-000000"}' | jq .
```

Legacy/mock `/auth/brunei_id` returns the generic account-not-found response. The OIDC callback
path with `audience = "fisherman"` returns the Flow B-specific response:

```json
{
  "status": "fail",
  "message": "No Fisherman account has been provisioned for this IC number. Please contact DoFI or your company administrator.",
  "code": "fisherman_account_not_provisioned"
}
```

There is no Fisherman registration redirect and no `CompanyProfileContact` fallback.

## Part C - Fisherman Source B: Owner-Created Teammate

After an Owner is active, Fisherman User Management can provision custom-role teammates:

```bash
curl -s -X POST "$BASE_URL/api/v1/fisherman/users" \
  -H "Authorization: $FISHERMAN_TOKEN" -H "Content-Type: application/json" \
  -d '{
    "user": {
      "name": "Test Fisherman Admin",
      "ic_number": "01-800211",
      "registration_type": "Commercial",
      "role_id": "admin-or-custom-role-id"
    }
  }' | jq .
```

Source B users start as `claimable`, the same as Source A. System Owner/Admin role assignment is
blocked through Fisherman User Management.

## Part D - Officer-Created Jetty Manager

**1. Create the Jetty Manager as a DoFi Officer.** It starts `active`.

```bash
curl -s -X POST "$BASE_URL/api/v1/admin/external_users/jetty_managers" \
  -H "Authorization: $OFFICER_TOKEN" -H "Content-Type: application/json" \
  -d '{
    "jetty_manager": {
      "name": "Test Jetty Manager",
      "ic_number": "01-800301",
      "unit": "Docks",
      "position": "Jetty Supervisor"
    }
  }' | jq .
```

**2. Log in with BruneiID straight away.**

```bash
curl -s -D - -X POST "$BASE_URL/api/v1/auth/brunei_id" \
  -H "Content-Type: application/json" \
  -d '{"ic_number": "01-800301", "audience": "jetty_manager"}'
```

**3. Unknown Jetty Manager IC stops.**

```bash
curl -s -X POST "$BASE_URL/api/v1/auth/brunei_id" \
  -H "Content-Type: application/json" \
  -d '{"ic_number": "00-000000", "audience": "jetty_manager"}' | jq .
```

This returns 404 with `code: "jetty_manager_account_not_provisioned"`. Jetty Manager uses
`users.status`, not `fisherman_status`.

## Testing via Postman

Use these folders in `postman/DoFi-Backend.postman_collection.json`:

- **Auth**: officer sign-in, seeded active Fisherman login, first-scan claim of a freshly profiled
  Fisherman, and unknown IC.
- **Profiling**: Company Profile creation that provisions Source A Owner/Admin users.
- **External Users**: Jetty Manager create → BruneiID login → deactivate/reactivate, and the
  Fisherman tab's list/show of Source A Owner/Admin users.
- **Users -> Fisherman**: Source B teammate provisioning and Owner-governance negative examples.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Fisherman login returns no token | User is `suspended` or `revoked` | Reactivate via External Users, or re-provision a revoked contact |
| Jetty Manager login returns no token | User is `inactive` | Reactivate via External Users |
| Unknown IC does not open registration | Expected for both audiences | Ask DoFI (or the company admin, for Fisherman teammates) to provision the account |
| Duplicate IC errors | `normalized_ic_number` is globally unique across kept users | Use a fresh IC or release an unclaimed erroneous user through admin procedure |
| Fisherman User Management cannot assign Owner role | Expected governance rule | Owner governance is DoFI Profiling only |
