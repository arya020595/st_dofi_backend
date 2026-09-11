# CLAUDE.md

Guidance for Claude Code (and other contributors) when working in this repository.

## Project

DoFi Backend — the FINS Capture Fisheries module API. API-only Rails 8.1.3 app (no views/assets) backing vessels, crews, manifests, capture reports, and related reference data for fisheries reporting.

Stack: Ruby 3.4.7, PostgreSQL, Solid Queue/Solid Cache (DB-backed, no Redis), Devise + devise-jwt (auth) + Pundit (authorization), dry-monads (service layer), Blueprinter (serialization), Pagy + Ransack (pagination/search), Audited + Discard (audit trail/soft delete), MinIO/S3-compatible storage via Active Storage (file storage; Cloudinary is a legacy service kept only until the migration to MinIO completes), Faraday/JWT (BruneiID integration), Sentry + Lograge (monitoring).

See [README.md](README.md) for setup (Docker or manual Rails) and how to run tests/CI.

## Architecture: keep layers thin and separate

Controllers, models, and business logic each have one job. Don't let logic leak across layers.

- **Controllers** (`app/controllers`) — parse params, authorize, call one service/query, and render. No business rules or direct multi-step ActiveRecord orchestration.
- **Policies** (`app/policies`) — authorization only (`Pundit`). One policy owns exactly one permission resource. Keep predicates side-effect free.
- **Services** (`app/services`, create as needed) — business logic and multi-step workflows. Use `dry-monads` `Success`/`Failure` results instead of raising for expected failure paths; controllers pattern-match on the result instead of branching on exceptions. Delegate non-trivial SQL construction to a Query object.
- **Queries** (`app/queries`, create as needed) — read-only SQL/ActiveRecord construction. A `*Query` exposes `self.call(...)`; it contains no authorization, business rules, response formatting, or side effects.
- **Models** (`app/models`) — associations, validations, scopes, and persistence concerns only. If a method coordinates multiple models or external calls, it belongs in a service, not the model.
- **Blueprints** (`app/blueprints`, create as needed) — response shaping only, via Blueprinter. Don't compute business values inline in a blueprint field that aren't simple presentation logic.

## Mandatory Pundit/RBAC contract

These are repository invariants, not preferences. `bin/rbac-lint` and the policy contract tests must
reject code that violates them.

- Every concrete policy directly subclasses `ApplicationPolicy` and defines exactly one private,
  literal `permission_resource`. Do not use permission resource constants such as `RESOURCE`,
  `APPROVALS`, or `VERIFICATIONS`.
- Every canonical catalog resource is owned by exactly one concrete policy. Never reuse the same
  `permission_resource` in multiple policies.
- Never choose a permission resource from the user's audience/platform inside a policy. Admin and
  Fisherman actions keep the same Pundit action names; route audience gates the platform and
  `Policy::Scope` provides row-level isolation.
- A policy may authorize only its own resource. Never accept another resource's code as a fallback,
  and never pass multiple codes to `User#permission?`; that method intentionally accepts one code.
- Standard mapping is fixed: `index? -> .list`, `show? -> .view`, `create? -> .create`,
  `update? -> .update`, and `destroy? -> .delete`. Custom predicates map to the identically named
  action code. `new?`/`edit?` and true semantic aliases such as `tab_counts? = index?` are the only
  aliases.
- Standard predicates are inherited. Override one only to append a business predicate after the
  exact capability check, using `super && ...`. Custom predicates use `permitted?("action")`.
- When one model participates in another authorization resource, create another policy and dispatch
  it explicitly with Pundit's `policy_class:`/`policy_scope_class:`. For example, `ManifestPolicy`
  owns `manifests.*`; `ManifestApprovalPolicy` owns `manifest_approvals.*`.
- Policy scopes filter which rows can be observed; they do not substitute one capability for another.
  Preserve company/tenant scoping and load tenant-owned records through `policy_scope(...).find`.
- A policy shared between the `dofi_officer` and `fisherman` platforms for a tenant-owned
  (company-scoped) resource must define a private `owns_record?` and use it on every predicate that
  receives a persisted record — `super && owns_record?` on inherited predicates,
  `permitted?("action") && owns_record?` on custom ones — bypassed via `user.dofi_officer_platform? ||
...` so officer oversight is unaffected. This holds even when a controller already loads the record
  through a scoped chain; the policy is the last line of defense, not the controller. Never add it to
  `create?`/`index?`/any predicate a controller authorizes against the bare model class — there is no
  record to own yet. See `docs/rbac/platform-company-isolation.md` §4.5 for the full worked set.
- `Permission::Catalog` is the sole source of truth for canonical codes, actions, platform scope,
  labels, sections, and ordering. Seeds persist it; role create/update rejects codes absent from it.

Canonical policy shape:

```ruby
class DashboardPolicy < ApplicationPolicy
  private

  def permission_resource = "dashboard"
end
```

Policy with a state/ownership rule:

```ruby
class ExamplePolicy < ApplicationPolicy
  def update? = super && owns_record?
  def submit? = permitted?("submit") && record.draft?

  private

  def permission_resource = "examples"

  def owns_record? = user.dofi_officer_platform? || record.company_profile_id == user.company_profile_id
end
```

## SOLID, applied here

- **Single Responsibility** — one class, one reason to change. A controller action should be ~5-10 lines: authorize, delegate to a service or model scope, render. If a model or controller method does several unrelated things, extract a service object named for what it does (`Manifests::SubmitForApproval`, not `ManifestHelper`).
- **Open/Closed** — extend behavior via new policies, services, or concerns rather than adding conditionals to existing classes. Example: a new role's permissions should be a new `Permission`/`Role` row and policy check, not an `if role == "x"` branch sprinkled through controllers.
- **Liskov Substitution** — every `ApplicationPolicy` subclass and `ApplicationRecord`/concern must honor the base contract (same method signatures, same meaning of return values) so callers can treat them interchangeably. Don't override a policy predicate to return something other than truthy/falsy, or a scope to return something other than a relation.
- **Interface Segregation** — prefer small, focused concerns/modules over one large mixin. If a concern grows methods unrelated to its name, split it.
- **Dependency Inversion** — services and jobs depend on injected collaborators (pass an HTTP client, mailer, or repository in), not hardcoded references, so they're testable in isolation. The BruneiID integration should go behind a small client class that controllers/services call, not inlined `Faraday` calls scattered across the codebase.

## Conventions

- Style is enforced by Rubocop (`.rubocop.yml`): double-quoted strings, no frozen-string-literal comment, 120-char line length. Run `bin/rubocop` before committing; don't hand-tune style that Rubocop already covers.
- Security: run `bin/brakeman` and `bin/bundler-audit` for anything touching auth, params, or external calls (`bin/ci` runs both).
- Tests: Minitest + FactoryBot + Faker, fixtures disabled (`fixture: false`) — use factories, not fixtures, for new tests. Tests run in parallel; keep them independent (no shared mutable state).
- Never reuse a client-writable display/business code (a `reference_id`-style column) as an internal
  type/role discriminator for business logic. If a model needs a small, fixed set of system-recognized
  kinds, add a dedicated column excluded from controller mass-assignment, nullable so it doesn't force
  custom/future records into one of the fixed buckets, seeded via `db/seeds`. See `Role#kind` and
  `docs/registration/business-flow.md` §2/§9 for the worked example and the incident that motivated it.
- Soft-deletable/audited models use `Discard`/`Audited` consistently with existing models rather than rolling a custom `deleted_at` flag.
- Background work goes through Solid Queue (`ApplicationJob` subclasses), not inline blocking calls in requests.

## Definition of done

Before considering a change complete: `bin/rbac-lint`, `bin/rubocop`, `bin/rails test`, and (for anything security-sensitive) `bin/brakeman` all pass. Prefer `bin/ci` for a full check.
