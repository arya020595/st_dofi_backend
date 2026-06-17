# CLAUDE.md

Guidance for Claude Code (and other contributors) when working in this repository.

## Project

DoFi Backend — the FINS Capture Fisheries module API. API-only Rails 8.1.3 app (no views/assets) backing vessels, crews, manifests, capture reports, and related reference data for fisheries reporting.

Stack: Ruby 3.4.7, PostgreSQL + PostGIS, Solid Queue/Solid Cache (DB-backed, no Redis), Devise + devise-jwt (auth) + Pundit (authorization), dry-monads (service layer), Blueprinter (serialization), Pagy + Ransack (pagination/search), Audited + Discard (audit trail/soft delete), Cloudinary (file storage), Faraday/JWT (BruneiID integration), Sentry + Lograge (monitoring).

See [README.md](README.md) for setup (Docker or manual Rails) and how to run tests/CI.

## Architecture: keep layers thin and separate

Controllers, models, and business logic each have one job. Don't let logic leak across layers.

- **Controllers** (`app/controllers`) — parse params, call one policy/service, render a response. No business rules, no direct multi-step ActiveRecord orchestration.
- **Policies** (`app/policies`) — authorization only (`Pundit`). One policy per model, subclassing `ApplicationPolicy`. Keep predicate methods (`show?`, `create?`, ...) free of side effects.
- **Services** (`app/services`, create as needed) — business logic and multi-step workflows. Use `dry-monads` `Success`/`Failure` results instead of raising for expected failure paths; controllers pattern-match on the result instead of branching on exceptions.
- **Models** (`app/models`) — associations, validations, scopes, and persistence concerns only. If a method coordinates multiple models or external calls, it belongs in a service, not the model.
- **Blueprints** (`app/blueprints`, create as needed) — response shaping only, via Blueprinter. Don't compute business values inline in a blueprint field that aren't simple presentation logic.

## SOLID, applied here

- **Single Responsibility** — one class, one reason to change. A controller action should be ~5-10 lines: authorize, delegate to a service or model scope, render. If a model or controller method does several unrelated things, extract a service object named for what it does (`Manifests::SubmitForApproval`, not `ManifestHelper`).
- **Open/Closed** — extend behavior via new policies, services, or `Mobility`/concerns rather than adding conditionals to existing classes. Example: a new role's permissions should be a new `Permission`/`Role` row and policy check, not an `if role == "x"` branch sprinkled through controllers.
- **Liskov Substitution** — every `ApplicationPolicy` subclass and `ApplicationRecord`/concern must honor the base contract (same method signatures, same meaning of return values) so callers can treat them interchangeably. Don't override a policy predicate to return something other than truthy/falsy, or a scope to return something other than a relation.
- **Interface Segregation** — prefer small, focused concerns/modules over one large mixin. If a concern grows methods unrelated to its name, split it.
- **Dependency Inversion** — services and jobs depend on injected collaborators (pass an HTTP client, mailer, or repository in), not hardcoded references, so they're testable in isolation. The BruneiID integration should go behind a small client class that controllers/services call, not inlined `Faraday` calls scattered across the codebase.

## Conventions

- Style is enforced by Rubocop (`.rubocop.yml`): double-quoted strings, no frozen-string-literal comment, 120-char line length. Run `bin/rubocop` before committing; don't hand-tune style that Rubocop already covers.
- Security: run `bin/brakeman` and `bin/bundler-audit` for anything touching auth, params, or external calls (`bin/ci` runs both).
- Tests: Minitest + FactoryBot + Faker, fixtures disabled (`fixture: false`) — use factories, not fixtures, for new tests. Tests run in parallel; keep them independent (no shared mutable state).
- Bilingual fields (EN/MS) go through `Mobility`, not ad hoc `_en`/`_ms` columns.
- Soft-deletable/audited models use `Discard`/`Audited` consistently with existing models rather than rolling a custom `deleted_at` flag.
- Background work goes through Solid Queue (`ApplicationJob` subclasses), not inline blocking calls in requests.

## Definition of done

Before considering a change complete: `bin/rubocop`, `bin/rails test`, and (for anything security-sensitive) `bin/brakeman` all pass. Prefer `bin/ci` for a full check.
