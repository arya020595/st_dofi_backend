# 2. Architecture

## 2.1 System context

Who talks to whom. The only new external dependency is Active Directory, and only in production.

```mermaid
flowchart LR
    subgraph Browser["Browser"]
        FE["DoFi frontend"]
    end

    subgraph Server["DoFi backend server"]
        API["Rails API<br/>Devise + devise-jwt"]
        PG[("PostgreSQL<br/>users, roles, jti")]
        API --- PG
    end

    AD["Active Directory<br/>MPRT.EG.GOV.BN<br/>LDAPS 3269 / 636"]
    BID["BruneiID<br/>(Fishermen, Jetty Managers)"]

    FE -- "POST /api/v1/auth/sign_in<br/>staff: AD name + password" --> API
    API -- "LDAPS bind<br/>(production only)" --> AD
    FE -- "BruneiID QR flow" --> API
    API --- BID
    FE -- "Bearer JWT on every request" --> API
```

In local and staging the arrow to AD does not exist: `MockLdapAuthenticator` answers inside the Rails process.

## 2.2 Layers

The code follows the repository's thin-layer rules ([`CLAUDE.md`](../../CLAUDE.md)): each class has one job.

```mermaid
flowchart TB
    subgraph L1["HTTP / framework layer"]
        RA["Rack::Attack<br/>10 sign-ins / min / IP"]
        SC["Api::V1::SessionsController#create"]
        DW["Devise + Warden"]
    end
    subgraph L2["Adapter layer (translation only)"]
        ST["ActiveDirectoryStrategy<br/>Success/Failure to success! / pass / fail! / custom!"]
    end
    subgraph L3["Business layer (services, dry-monads)"]
        OL["OfficerLogin<br/>who may sign in, and the verdict"]
        DU["DirectoryUsername<br/>how a username is written"]
        DC["DirectoryConfig<br/>settings and boot guards"]
    end
    subgraph L4["Infrastructure layer (the directory)"]
        LA["LdapAuthenticator<br/>real AD over LDAPS"]
        MA["MockLdapAuthenticator<br/>shared password"]
        NL["net-ldap gem"]
    end
    subgraph L5["Data layer"]
        MU["User / Role models<br/>directory_managed, JTI, revocation"]
        PG[("PostgreSQL")]
    end

    RA --> SC --> DW --> ST --> OL
    OL --> DU
    OL --> DC
    OL --> MU --> PG
    OL --> LA --> NL
    OL --> MA
```

| Layer | Class | Single responsibility | Knows nothing about |
|---|---|---|---|
| Adapter | `ActiveDirectoryStrategy` | Translate `OfficerLogin`'s answer to Warden calls | LDAP, roles, status rules |
| Business | `OfficerLogin` | Find the staff user, check eligibility, ask the directory, log | HTTP, Warden, LDAP networking |
| Business | `DirectoryUsername` | Turn typed text into stored-username candidates / the AD short name | Users, the database, AD |
| Business | `DirectoryConfig` | Read and validate every AD setting once | Everything else |
| Infrastructure | `LdapAuthenticator` | One LDAPS bind with TLS, timeouts, failover | Users, roles, DoFi accounts |
| Infrastructure | `MockLdapAuthenticator` | The same contract as `LdapAuthenticator`, with a shared password | Users, roles |
| Data | `User`, `Role` | Who is staff; token revocation | LDAP, HTTP |

### The shared contract (Liskov)

`LdapAuthenticator` and `MockLdapAuthenticator` are interchangeable. Both implement:

```
call(username:, password:)  ->  Success(:authenticated)
                             |  Failure(:invalid_credentials)    the directory said no
                             |  Failure(:directory_unavailable)  the directory could not be asked
```

`OfficerLogin` receives one of them (by default chosen from `AD_MODE`) and never branches on which it is. A shared
test module (`test/support/directory_authenticator_contract.rb`) runs the same assertions against both classes, so any
future authenticator must honour the same contract.

## 2.3 Class diagram

```mermaid
classDiagram
    class ActiveDirectoryStrategy {
        +authenticate!()
        -unavailable_response()
    }
    class OfficerLogin {
        +call(username, password) Result
        -staff_matching(typed)
        -decide(matches, password)
        -authenticate(user, password)
        -log(user, result, reason, started)
    }
    class DirectoryUsername {
        +short() String
        +stored_candidates() Array
        SHORT_NAME regex
    }
    class DirectoryConfig {
        +mode
        +deploy_env
        +hosts
        +port
        +netbios_domain
        +dns_domain
        +bind_format
        +ca_file
        +mock_password
        +mock?()
        +ldap?()
        +production?()
        +problems() Array
        +current()$ DirectoryConfig
        +load(env, rails_env)$ DirectoryConfig
    }
    class LdapAuthenticator {
        +call(username, password) Result
        -bind(username, password)
        -tls_options()
    }
    class MockLdapAuthenticator {
        +call(username, password) Result
        UNAVAILABLE_PASSWORD
    }
    class User {
        +directory_managed?()
        +valid_password?(pw)
        +active_for_authentication?()
        -revoke_tokens()
        -token_revocation_needed?()
    }
    class Role {
        +directory_managed?()
        +directory_managed()$ Relation
    }

    ActiveDirectoryStrategy --> OfficerLogin : calls
    OfficerLogin --> DirectoryUsername : parses names
    OfficerLogin --> DirectoryConfig : reads
    OfficerLogin --> User : finds staff
    OfficerLogin --> LdapAuthenticator : mode ldap
    OfficerLogin --> MockLdapAuthenticator : mode mock
    LdapAuthenticator --> DirectoryConfig
    MockLdapAuthenticator --> DirectoryConfig
    User --> Role : belongs_to
```

`DirectoryConfig` is a Ruby `Data` object: immutable, built once, read everywhere. That is why tests can pass a
different config to any service instead of changing global state.

## 2.4 Which strategy answers? (Warden order)

Devise keeps an ordered list of Warden strategies for the `user` scope. `devise.rb` puts ours **first**:

```mermaid
flowchart LR
    REQ["POST /auth/sign_in<br/>user[username], user[password]"] --> S1["1. active_directory<br/>(ours)"]
    S1 -- "success!" --> OK["signed in"]
    S1 -- "fail!" --> NO["401, chain stops"]
    S1 -- "custom! 503" --> UN["503, chain stops"]
    S1 -- "pass (not staff)" --> S2["2. the other Devise strategies<br/>(database_authenticatable: local password)"]
    S2 --> OK2["Fisherman / Jetty Manager signs in<br/>or 401"]
```

Why "first" matters: for a staff user the strategy answers `success!`, `fail!` or `custom!`, all of which **stop the
chain**. The local password strategy is never consulted. It only runs when ours says `pass` ("not mine"), which
happens for usernames that are not staff.

As a second wall, `User#valid_password?` returns `false` for staff, so even if a code change one day let the chain
reach `database_authenticatable`, a staff user still could not get in with whatever hash their row might hold.

## 2.5 Environments

```mermaid
flowchart TB
    subgraph Local["Local development / tests"]
        L1["RAILS_ENV=development or test<br/>DEPLOY_ENV unset (= RAILS_ENV)<br/>AD_MODE=mock (default)"]
    end
    subgraph Stg["Staging server"]
        S1["RAILS_ENV=production<br/>DEPLOY_ENV=staging<br/>AD_MODE=mock (or ldap)"]
    end
    subgraph Prd["Production server"]
        P1["RAILS_ENV=production<br/>DEPLOY_ENV=production<br/>AD_MODE=ldap"]
    end
    Local --> M["Mock directory<br/>shared AD_MOCK_PASSWORD"]
    Stg --> M
    Prd --> R["Real AD over LDAPS"]
```

| | Local / tests | Staging | Production |
|---|---|---|---|
| `RAILS_ENV` | development / test | **production** | production |
| `DEPLOY_ENV` | unset (falls back to `RAILS_ENV`) | `staging` | `production` |
| `AD_MODE` | `mock` (default) | `mock`, or `ldap` to try the real AD | `ldap` (required) |
| Staff password | shared `AD_MOCK_PASSWORD` | shared `AD_MOCK_PASSWORD` | each person's AD password |
| Demo seeds | loaded | loaded | **never** |

### Why `DEPLOY_ENV` exists

`RAILS_ENV=production` is true on **both** staging and production, so the code cannot tell them apart. A second
variable, `DEPLOY_ENV`, says which deployment it is. It is set in each deployment's **compose file**, not in the
server's `.env`: in Docker Compose an `environment:` entry overrides `env_file`, so a stray line in a `.env` cannot flip
production to staging. `test/config/deployment_environment_test.rb` reads the compose files and fails if an edit weakens
this.

## 2.6 The boot guard

`DirectoryConfig.load` runs when the app boots (and for `db:prepare`, `db:seed` and the console). It **raises** if the
combination is unsafe, so a typo cannot silently leave staff on a weaker path.

```mermaid
flowchart TD
    A["App boots"] --> B{"RAILS_ENV = production?"}
    B -- Yes --> C{"DEPLOY_ENV is<br/>staging or production?"}
    C -- No --> X1["BOOT ERROR<br/>DEPLOY_ENV must be one of ..."]
    C -- Yes --> D{"AD_MODE set?"}
    B -- No --> D2["DEPLOY_ENV = RAILS_ENV<br/>AD_MODE defaults to mock"]
    D -- No --> X2["BOOT ERROR<br/>AD_MODE must be mock or ldap"]
    D -- Yes --> E
    D2 --> E{"AD_MODE is mock or ldap?"}
    E -- "No (disabled, typo...)" --> X3["BOOT ERROR"]
    E -- Yes --> F{"mock AND<br/>DEPLOY_ENV = production?"}
    F -- Yes --> X4["BOOT ERROR<br/>mock not allowed on production"]
    F -- No --> OK["Boots"]
```

Anything that is wrong but not dangerous does **not** stop the boot, it makes sign-in answer 503. For example, a
missing `AD_HOST` or an unreadable CA file: `DirectoryConfig#problems` lists the reasons, the authenticator logs them
and returns `directory_unavailable`. The app stays up for Fishermen and Jetty Managers.

## 2.7 Data model touched

No new table and no new column. AD reuses existing data:

| Column | Role in AD sign-in |
|---|---|
| `users.username` | The sign-in identity. Staff: `mprt/<ad name>`. Changing it revokes tokens. |
| `users.status` | `active` is required to sign in. `inactive` and `suspended` deny access. |
| `users.discarded_at` | Soft delete (Discard). Non-null denies access. |
| `users.fisherman_status` | The Fisherman's lifecycle; `suspended` and `revoked` deny access. |
| `users.jti` | The token id. Changing it kills every token issued before. |
| `users.encrypted_password` | Empty for staff: no password is required or stored (`User#password_required?`). |
| `roles.platform_scope`, `roles.kind` | Decide whether a user is staff. |

## 2.8 Design decisions and why

| Decision | Reason |
|---|---|
| Warden strategy instead of a custom controller | The endpoint, the JWT dispatch and the response body stay exactly as they were. |
| `OfficerLogin` returns `dry-monads` results | The repository's service convention; no exceptions for expected failures; `case/in` pattern matching in the strategy. |
| Two authenticator classes with one contract | Local and staging can run without an AD server; production code path is identical above the authenticator. |
| `AD_MODE` has no `disabled` value | A "turn it off" switch is how a typo ends with staff on a weaker path. |
| `DirectoryConfig` is the only reader of `ENV` | One place to validate; everything else receives a config object (testable, injectable). |
| Reuse `JTIMatcher` for revocation | Already installed, already revokes on sign-out, no new table or cache. |
| Reuse Devise's `active_for_authentication?` | Devise already calls it on every authenticated request, JWT included. |
| Identical 401 for every refusal | Prevents account enumeration. |
| Bind identity built from the **stored** username | Typed text never reaches the LDAP bind identity, so no LDAP-injection style tricks. |
| Mock password is one shared value, not per user | Matches how the client wants to test: many officers, one environment password, no extra storage. |
