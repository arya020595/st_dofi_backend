# 4. Sequence diagrams

Each diagram is one scenario. Participants:

- **FE**: the DoFi frontend (browser)
- **Rack**: Rack::Attack and Devise middleware
- **Strategy**: `ActiveDirectoryStrategy`
- **Login**: `OfficerLogin`
- **Auth**: `LdapAuthenticator` or `MockLdapAuthenticator`
- **DB**: PostgreSQL
- **AD**: Active Directory

## 4.1 Successful staff sign-in (production, `AD_MODE=ldap`)

```mermaid
sequenceDiagram
    autonumber
    actor Officer
    participant FE as Frontend
    participant Rack as Rack / Devise
    participant Strategy as ActiveDirectoryStrategy
    participant Login as OfficerLogin
    participant DB as PostgreSQL
    participant Auth as LdapAuthenticator
    participant AD as Active Directory

    Officer->>FE: types MPRT/Azri.Nizam + AD password
    FE->>Rack: POST /api/v1/auth/sign_in {user:{username,password}}
    Rack->>Rack: throttle check (10/min/IP)
    Rack->>Strategy: authenticate!
    Strategy->>Login: call(username, password)
    Login->>Login: DirectoryUsername to candidates ["mprt/azri.nizam","azri.nizam"]
    Login->>DB: User.directory_managed WHERE username IN (...) LIMIT 2
    DB-->>Login: 1 row (active, kept)
    Login->>Login: short name from the stored username = "azri.nizam"
    Login->>Auth: call(username: "azri.nizam", password)
    Auth->>Auth: usable? config.problems empty?
    Auth->>AD: LDAPS connect, verify certificate and host name
    Auth->>AD: simple bind as MPRT\azri.nizam
    AD-->>Auth: bind OK
    Auth-->>Login: Success(:authenticated)
    Login->>Login: log ad.login success
    Login-->>Strategy: Success(user)
    Strategy->>Rack: success!(user)
    Rack->>Rack: activatable: active_for_authentication? true
    Rack->>Rack: devise-jwt creates JWT with users.jti
    Rack-->>FE: 200 {access_token, user, cable token}
    FE-->>Officer: signed in
```

## 4.2 Successful staff sign-in (local / staging, `AD_MODE=mock`)

Identical above the authenticator. Only steps 11 to 13 change:

```mermaid
sequenceDiagram
    autonumber
    participant Login as OfficerLogin
    participant Auth as MockLdapAuthenticator
    participant Cfg as DirectoryConfig

    Login->>Auth: call(username: "azri.nizam", password)
    Auth->>Cfg: problems? mock_password set?
    Cfg-->>Auth: none
    Auth->>Auth: secure_compare(password, AD_MOCK_PASSWORD)
    Auth-->>Login: Success(:authenticated)
```

No network, no AD. Any staff user, one shared password.

## 4.3 Wrong password

```mermaid
sequenceDiagram
    autonumber
    participant FE as Frontend
    participant Strategy as ActiveDirectoryStrategy
    participant Login as OfficerLogin
    participant Auth as LdapAuthenticator
    participant AD as Active Directory

    FE->>Strategy: sign_in azri.nizam + wrong password
    Strategy->>Login: call
    Login->>Auth: call(username, password)
    Auth->>AD: simple bind
    AD-->>Auth: result code 49 invalidCredentials
    Auth-->>Login: Failure(:invalid_credentials)
    Login->>Login: log ad.login failure reason=invalid_credentials
    Login-->>Strategy: Failure(:invalid_credentials)
    Strategy->>FE: fail!(:invalid) so 401 generic body
```

Only one domain controller is asked: a rejection is never replayed on the next host (lockout protection).

## 4.4 Unknown user, inactive user, Fisherman (the directory is not asked)

```mermaid
sequenceDiagram
    autonumber
    participant FE as Frontend
    participant Strategy as ActiveDirectoryStrategy
    participant Login as OfficerLogin
    participant DB as PostgreSQL
    participant Devise as Devise local strategy

    rect rgb(240,248,255)
    Note over FE,Devise: A) Username is not a staff user (unknown, Fisherman, Jetty Manager)
    FE->>Strategy: sign_in someone
    Strategy->>Login: call
    Login->>DB: staff lookup
    DB-->>Login: no rows
    Login-->>Strategy: Failure(:not_applicable)
    Strategy->>Devise: pass
    Devise-->>FE: normal local check: Fisherman signs in, unknown gets 401
    end

    rect rgb(255,245,240)
    Note over FE,Devise: B) Staff user exists but is inactive / suspended / discarded
    FE->>Strategy: sign_in azri.nizam + correct password
    Strategy->>Login: call
    Login->>DB: staff lookup
    DB-->>Login: 1 row, status inactive
    Login->>Login: ineligible_account (no directory call)
    Login-->>Strategy: Failure(:invalid_credentials)
    Strategy-->>FE: 401 generic
    end
```

## 4.5 Directory unavailable (503)

```mermaid
sequenceDiagram
    autonumber
    participant FE as Frontend
    participant Strategy as ActiveDirectoryStrategy
    participant Login as OfficerLogin
    participant Auth as LdapAuthenticator
    participant AD as Active Directory
    participant Log as ApplicationLogger

    FE->>Strategy: sign_in
    Strategy->>Login: call
    Login->>Auth: call(username, password)
    Auth->>AD: LDAPS connect
    AD--xAuth: timeout / refused / TLS error
    Auth->>Log: ad.directory_unavailable (exception class only)
    Auth-->>Login: Failure(:directory_unavailable)
    Login-->>Strategy: Failure(:directory_unavailable)
    Strategy-->>FE: custom! 503 {"message":"Sign-in is temporarily unavailable..."}
    Note over FE: Fishermen and Jetty Managers still sign in (they never reach AD)
```

The same 503 appears when the configuration is incomplete (`config.problems` is not empty), without any network call.

## 4.6 Sign-out

```mermaid
sequenceDiagram
    autonumber
    actor Officer
    participant FE as Frontend
    participant Rack as devise-jwt middleware
    participant Ctl as SessionsController#destroy
    participant DB as PostgreSQL

    Officer->>FE: clicks Sign out
    FE->>Rack: DELETE /api/v1/auth/sign_out (Bearer JWT)
    Rack->>Ctl: request passes the JWT strategy
    Ctl-->>Rack: 200 "Signed out successfully."
    Rack->>DB: UPDATE users SET jti = new random value (after the response)
    Rack-->>FE: 200
    FE->>FE: clear stored token and auth state
    Note over FE,DB: Any later request with the old JWT: jti no longer matches users.jti, so 401
```

The controller never touches `jti`. devise-jwt's `RevocationManager` middleware does it once, because the route is in
`jwt.revocation_requests`. A test counts the `UPDATE ... "jti"` statements and asserts exactly one.

## 4.7 Admin deactivates an officer who is signed in

```mermaid
sequenceDiagram
    autonumber
    actor Admin
    actor Officer
    participant API as Rails API
    participant User as User model
    participant DB as PostgreSQL

    Officer->>API: GET /api/v1/manifests (Bearer JWT-1)
    API-->>Officer: 200
    Admin->>API: PATCH /api/v1/admin/users/:id {status: "inactive"}
    API->>User: update(status: "inactive")
    User->>User: before_save: access changed AND not active_for_authentication?
    User->>DB: UPDATE users SET status='inactive', jti=NEW
    Officer->>API: GET /api/v1/manifests (Bearer JWT-1)
    API->>API: JWT strategy: jti mismatch, and active_for_authentication? false
    API-->>Officer: 401 generic
    Admin->>API: PATCH /api/v1/admin/users/:id {status: "active"}
    API->>User: update(status: "active")
    User->>User: nothing to rotate: access is allowed again
    Officer->>API: GET /api/v1/manifests (Bearer JWT-1)
    API-->>Officer: 401 (JWT-1 stays dead)
    Officer->>API: sign in again (AD password)
    API-->>Officer: 200 + JWT-2
```

The same happens for the AASM events (`deactivate!`, `suspend!`, the Fisherman and Jetty Manager `.../deactivate`
endpoints) and for a soft delete (`discard`): the rule lives in the model callback, not in any one endpoint.

Two independent walls stop JWT-1: the changed `jti`, and `active_for_authentication?`. The `jti` change is what
keeps JWT-1 dead after reactivation.

## 4.8 Admin changes a username

```mermaid
sequenceDiagram
    autonumber
    actor Admin
    participant API as Rails API
    participant User as User model
    participant DB as PostgreSQL
    actor Officer

    Admin->>API: PATCH /api/v1/admin/users/:id {username: "mprt/new.name"}
    API->>User: update(username)
    User->>User: will_save_change_to_username? yes
    User->>DB: UPDATE users SET username='mprt/new.name', jti=NEW
    Officer->>API: request with the old JWT
    API-->>Officer: 401
    Officer->>API: sign in as new.name + AD password
    API-->>Officer: 200 + new JWT
    Officer->>API: sign in as old.name
    API-->>Officer: 401 (no such staff user)
```

A name, phone, position, unit, email or locale change fires **no** rotation, so those edits never log anyone out.

## 4.9 Boot-time guard

```mermaid
sequenceDiagram
    autonumber
    participant Ops as Operator
    participant Compose as docker compose
    participant Rails as Rails boot
    participant Cfg as DirectoryConfig.load

    Ops->>Compose: docker compose up (production)
    Compose->>Rails: env RAILS_ENV=production, DEPLOY_ENV=production + server .env
    Rails->>Cfg: after_initialize: DirectoryConfig.current
    alt AD_MODE=mock on production
        Cfg-->>Rails: raise ArgumentError "AD_MODE=mock is not allowed when DEPLOY_ENV=production"
        Rails-->>Ops: container exits, nobody can sign in
    else AD_MODE=ldap
        Cfg-->>Rails: config object
        Rails-->>Ops: app up
    end
```

## 4.10 Production cut-over for the superadmin

```mermaid
sequenceDiagram
    autonumber
    actor Eng as Engineer (via Delinea)
    participant Srv as Backend server
    participant AD as AD team
    participant DB as PostgreSQL

    Eng->>AD: confirm hosts, port, bind format, CA PEM
    Eng->>Srv: set AD_MODE=ldap and AD_* in .env, mount CA file
    Eng->>Srv: bin/rails admin:assign_ad_username EMAIL=admin@dofi.gov.bn AD_USERNAME=mprt/real.name
    Srv->>DB: UPDATE users SET username, jti (single row)
    Eng->>Srv: start api container
    Eng->>Srv: test sign-in with a dedicated AD test account
    Note over Eng,Srv: Rollback = stop the container. There is no local-password mode.
```

## 4.11 Fresh database seeding

```mermaid
sequenceDiagram
    autonumber
    participant Ops as Operator
    participant Seeds as db/seeds.rb
    participant Cfg as DirectoryConfig
    participant Admin as seeds/admin_user.rb

    Ops->>Seeds: bin/rails db:seed
    Seeds->>Seeds: reference files (permissions, roles, admin_user, ports...)
    Seeds->>Admin: load
    alt production and ADMIN_AD_USERNAME missing or invalid
        Admin-->>Ops: abort: set ADMIN_AD_USERNAME to the real AD username
    else
        Admin->>Admin: find_or_create_by!(email) (existing row untouched)
    end
    Seeds->>Cfg: production?
    alt DEPLOY_ENV=production
        Seeds-->>Ops: "skipping the demo seeds"
    else
        Seeds->>Seeds: demo files (companies, crews, profiled_users, manifests...)
    end
```
