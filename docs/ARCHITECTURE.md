# Architecture Overview

The orientation doc for this repo — how the app is layered, what runs where, and how the core
domain fits together. Each section links to the topic folder that covers it in depth; this doc
stays intentionally at the "one screen" level rather than duplicating those.

## Tech stack at a glance

| Concern | Choice |
|---|---|
| Language / framework | Ruby 3.4.7, Rails 8.1.3 (API-only, no views/assets) |
| Database | PostgreSQL |
| Background jobs / cache | Solid Queue / Solid Cache — DB-backed, no Redis |
| Auth | Devise + devise-jwt (JWT sessions) |
| Authorization | Pundit (one policy per model) |
| Service layer | dry-monads (`Success`/`Failure` results, not exceptions, for expected failure paths) |
| State machine | AASM (e.g. `User#status`, manifest/approval lifecycles) |
| Serialization | Blueprinter |
| Search / pagination | Ransack / Pagy |
| Audit trail / soft delete | Audited / Discard |
| File storage | MinIO (self-hosted, S3-compatible) via Active Storage; Cloudinary kept only until migration completes |
| External identity | BruneiID (government ID verification) via `Faraday`/`jwt` — **mocked today**, see §1 |
| Bilingual fields (EN/MS) | Mobility |
| Monitoring | Sentry (errors) + Lograge (structured JSON request logs) |

## 1. System context

Who the app talks to, and how.

```mermaid
graph LR
    FE["Frontend<br/>(separate repo)"]
    API["DoFi Backend<br/>Rails 8.1.3 API-only"]
    DB[("PostgreSQL<br/>+ Solid Queue/Cache")]
    MINIO[("MinIO<br/>self-hosted S3-compatible storage")]
    BID["BruneiID<br/>gov identity verification<br/>(mocked today)"]
    SENTRY["Sentry<br/>error monitoring"]
    GH["GitHub Actions<br/>CI/CD"]
    GHCR[("GHCR<br/>image registry")]

    FE -->|HTTPS, JWT bearer token| API
    API --> DB
    API -->|SigV4 signed, uploads/downloads| MINIO
    FE -.->|presigned / direct public URLs| MINIO
    API -.->|IC number verification<br/>app/services/brunei_id/client.rb, mocked| BID
    API -->|errors, 10% trace sampling| SENTRY
    GH -->|build & push image| GHCR
    GH -->|SSH, pull + migrate + up| API
```

BruneiID is dashed because it's not a real integration yet — `app/services/brunei_id/client.rb`
trusts the frontend-supplied IC number as already verified (the same trust boundary
self-registration already relies on). The `faraday`/`jwt` gems and `BRUNEIID_*` env vars are
reserved for when it becomes real; the swap only touches that one class. See
[`docs/registration/business-flow.md`](registration/business-flow.md) §10 for the full mocked-vs-real
breakdown across the app.

## 2. Deployment topology

Staging is one server; production is three separate government-provided servers. Both are
generalized here — see [`docs/minio/MINIO.md`](minio/MINIO.md) §2 for why MinIO specifically is
loopback-only + reverse-proxied, and [`docs/ci-cd/CI-CD-SETUP.md`](ci-cd/CI-CD-SETUP.md) for the
full CI/CD pipeline.

```mermaid
graph TB
    subgraph Staging["Staging — single server"]
        SPROXY["host nginx<br/>reverse proxy"]
        SAPI["api container"]
        SJOBS["jobs container<br/>Solid Queue"]
        SDB[("db container<br/>Postgres")]
        SMINIO[("minio container<br/>127.0.0.1 only")]
        SPROXY --> SAPI
        SPROXY -.->|image URLs| SMINIO
        SAPI --> SDB
        SJOBS --> SDB
        SAPI --> SMINIO
        SJOBS --> SMINIO
    end
    SFE["Frontend"] -->|"HTTPS :3012"| SPROXY

    subgraph Production["Production — 3 dedicated government servers"]
        subgraph PBackend["Backend server"]
            PPROXY["reverse proxy<br/>host nginx or nginx sidecar"]
            PAPI["api container"]
            PJOBS["jobs container"]
            PMINIO[("minio container<br/>127.0.0.1 only")]
            PPROXY --> PAPI
            PPROXY -.->|image URLs| PMINIO
            PAPI --> PMINIO
            PJOBS --> PMINIO
        end
        subgraph PDBServer["Database server (dedicated)"]
            PDB[("PostgreSQL")]
        end
        subgraph PFEServer["Frontend server (separate repo)"]
            PFE["Frontend app"]
        end
        PAPI -->|"DATABASE_HOST, private network + TLS"| PDB
        PJOBS -->|"DATABASE_HOST"| PDB
        PFE -->|HTTPS| PPROXY
    end
```

Key differences from staging: production's `docker-compose.production.yml` has **no `db:`
service** at all (the database server is entirely outside this repo's compose files), and its
`deploy` job is gated behind a GitHub `production` Environment requiring human approval —
staging deploys on every push to `develop`, production only on `main` plus a reviewer sign-off.

## 3. Layered application architecture

Every request flows through the same five layers, each with exactly one job
(enforced in [`CLAUDE.md`](../CLAUDE.md)):

```mermaid
graph LR
    C["Controller<br/>app/controllers<br/>parse params, call one policy/service, render"]
    P["Policy<br/>app/policies<br/>Pundit — authorization only, no side effects"]
    S["Service<br/>app/services<br/>business logic — dry-monads Success/Failure"]
    M["Model<br/>app/models<br/>associations, validations, scopes"]
    B["Blueprint<br/>app/blueprints<br/>Blueprinter — response shaping only"]

    C -->|"authorize"| P
    C -->|"call(...)"| S
    S -->|"reads / writes"| M
    C -->|"render_as_hash"| B
    B -->|"reads"| M
```

### A concrete request, end to end

`POST /api/v1/fisherman/manifests` — a fisherman filing a new manifest:

```mermaid
sequenceDiagram
    participant FE as Frontend
    participant Ctrl as Fisherman::ManifestsController#create
    participant Pol as ManifestPolicy#create?
    participant Svc as Manifests::Create
    participant SetCrew as Manifests::SetCrew
    participant Mod as Manifest (ActiveRecord)
    participant BP as ManifestDetailBlueprint

    FE->>Ctrl: POST /api/v1/fisherman/manifests
    Ctrl->>Pol: authorize Manifest
    Pol-->>Ctrl: allowed
    Ctrl->>Svc: Manifests::Create.call(params, company_profile:, actor:)
    Svc->>Mod: build (vessel/captain snapshot, server-derived company_profile)
    alt vessel & captain approved, save succeeds
        Svc->>Mod: manifest.save! (transaction)
        Svc->>SetCrew: SetCrew.call(manifest, crew_ids:, ad_hoc_crew:)
        Svc-->>Ctrl: Success(manifest)
        Ctrl->>BP: ManifestDetailBlueprint.render_as_hash(manifest)
        BP-->>Ctrl: JSON hash
        Ctrl-->>FE: 201 Created
    else invalid (unapproved vessel/captain, validation failure)
        Svc-->>Ctrl: Failure(manifest)
        Ctrl-->>FE: 422 Unprocessable Content
    end
```

Source: [`app/controllers/api/v1/fisherman/manifests_controller.rb`](../app/controllers/api/v1/fisherman/manifests_controller.rb),
[`app/services/manifests/create.rb`](../app/services/manifests/create.rb).

### A recurring pattern: create → approve → resubmit

Four resource families — `CompaniesVessels`, `CompaniesCrews`, `CompaniesFishingGears`, and
`Manifests` — each go through an identical lifecycle, serviced by
near-identical service classes (`create`/`update`/`approve`/`request_amendment`/`resubmit`):

```mermaid
stateDiagram-v2
    [*] --> pending: create
    pending --> approved: approve
    pending --> amendment_requested: request_amendment
    amendment_requested --> pending: resubmit
```

This is the same shape as the Fisherman/Jetty Manager registration approval queue described in
[`docs/registration/business-flow.md`](registration/business-flow.md) §7 — one recurring engine, applied
independently per resource type via each resource's own policy/service pair rather than one shared
conditional (Open/Closed — see `CLAUDE.md`'s SOLID section).

## 4. Domain / entity overview

Simplified — grouped by area, not every column on all ~27 models. `db/schema.rb` is the source of
truth for exact columns; this is for orientation.

```mermaid
erDiagram
    Role ||--o{ User : "has"
    Role }o--o{ Permission : "granted via PermissionRole"
    CompanyProfile ||--o{ Role : "owns (fisherman-platform roles)"
    CompanyProfile ||--o{ User : "registers"
    CompanyProfile ||--o{ CompanyProfileContact : "Owner / Admin"
    CompanyProfile ||--o{ CompaniesVessel : "owns"
    CompanyProfile ||--o{ CompaniesCrew : "employs"
    CompanyProfile ||--o{ CompaniesFishingGear : "owns"
    CompanyProfile ||--o{ Manifest : "files"

    User ||--o{ Manifest : "created_by"
    Manifest }o--|| CompaniesVessel : "uses"
    Manifest }o--o| CompaniesCrew : "captain"
    Manifest }o--o{ CrewManifest : "crew aboard"
    Manifest ||--o| ManifestExpense : "has"
    Manifest ||--o{ CaptureReport : "has"
    Manifest }o--|| Port : "port_out / port_in"
    Manifest }o--o| Zone : "fishing zone"

    CaptureReport ||--o{ FishCaptureDetail : "has"
    CaptureReport ||--o{ FishingGearDetail : "has"
    CaptureReport }o--o| Zone : "zone"
```

**Master/reference data** — `Port`, `Zone`, `FishingGear`, `Nationality`, `Position`, `Dictionary`
(fish-species photos, public bucket — see [`docs/minio/MINIO-WHY-TWO-BUCKETS.md`](minio/MINIO-WHY-TWO-BUCKETS.md)),
and `ApprovalRemark` are lookup tables referenced from many places above (`Manifest.port_out`,
`CaptureReport.zone`, rejection reasons, etc.) rather than owned by any one domain area. All six
share the same CRUD/search shape — see [`docs/api/master-data.md`](api/master-data.md) and
[`docs/api/search-filter-sort-pagination.md`](api/search-filter-sort-pagination.md). Because these
are editable after the fact, `Manifest`/`CrewManifest`/`CompaniesFishingGear` and friends freeze the
fields that matter onto their own rows rather than only holding the foreign key — see
[`docs/data-model/denormalized-snapshots.md`](data-model/denormalized-snapshots.md).

## Where to go deeper

- [`docs/rbac/`](rbac/) — role-based access control: platform/company isolation, authorization vs.
  isolation, permissions model
- [`docs/registration/`](registration/) — actors, roles, registration & approval flow
- [`docs/api/`](api/) — frontend-facing request/response contracts
- [`docs/data-model/`](data-model/) — denormalized historical snapshots vs. live master-data references
- [`docs/minio/`](minio/) — file storage architecture & setup
- [`docs/ci-cd/`](ci-cd/) — CI/CD & deployment
- [`docs/incidents/`](incidents/) — postmortems & dated test reports
- [`CLAUDE.md`](../CLAUDE.md) — the layering/SOLID rules this doc's diagrams illustrate
