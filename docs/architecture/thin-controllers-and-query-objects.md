# Thin Controllers & Query Objects

The canonical shape for controller actions, when (and when not) to write a Query object or a
service, and how to keep a persisted aggregate in sync. This is the worked example behind
[`CLAUDE.md`](../../CLAUDE.md)'s "Mandatory controller/query shape contract" — read that section
first; this doc is the rationale and the fuller reference, not a duplicate of it.

## 1. Why this doc exists

An audit of the ten controllers under `app/controllers/api/v1/admin/` found four real deviations from
the pattern the rest of the codebase already follows:

- A raw SQL heredoc embedded directly in a controller to compute a correlated `COUNT(*)`.
- The same comma-separated multi-value param-parsing idiom reimplemented from scratch in three
  different controllers, each with slightly different variable names.
- Two sibling controllers (same shape: simple single/two-field CRUD) each inventing their own,
  mutually incompatible, bespoke CRUD-response indirection (`persist`/`render_resource` in one,
  `render_collection`/`create_resource`/`update_resource`/`destroy_resource` in the other) instead of
  the flat inline-render style every other controller already uses.

None of this was caught by Rubocop or the test suite — it's a consistency problem, not a correctness
one, and consistency problems only get worse over time without something to point at. This doc is
that something.

## 2. Decision tree

```mermaid
flowchart TD
    A["New index/show/create/update/destroy action"] --> B{"Business logic beyond<br/>model validations?"}
    B -->|No, plain CRUD| C["Call .save/.update/.destroy<br/>directly in the action, inline render"]
    B -->|Yes, multi-step workflow| D["Service object (app/services)<br/>dry-monads Success/Failure"]

    A --> E{"index/search action?"}
    E -->|"Plain column filter"| F["RansackSearchable + q[field_predicate]<br/>no controller code needed"]
    E -->|"Business logic Ransack can't express<br/>(value translation, mandatory scope,<br/>cross-table join)"| G["Query object (app/queries)<br/>self.call(scope:, ...)"]

    A --> H{"Per-row aggregate needed<br/>alongside pagination?"}
    H -->|"1-2 mutation sites"| I["Persisted column +<br/>explicit sync service call<br/>at each mutation site"]
    H -->|"3+ mutation sites,<br/>likely to grow"| J["Persisted column +<br/>model callback<br/>(after_create/after_discard/after_undiscard)"]
```

## 3. Controller action shape

Every action is: `authorize` → one call → inline `render`. No private `render_resource`/
`create_resource`/`persist` helper, no shared "render this resource" method invented for one
controller. See [`app/controllers/api/v1/admin/dictionaries_controller.rb`](../../app/controllers/api/v1/admin/dictionaries_controller.rb) —
`index`/`show`/`create`/`update`/`destroy` each render inline, including a plain
`if @dictionary.destroy ... else ... end` for the one action with no service behind it.

This looks repetitive across actions and across sibling controllers (`dictionary_families_controller.rb`
and `dictionary_groups_controller.rb` render almost-identical JSON shapes). That repetition is
intentional — three similar `render json:` blocks are more legible and more greppable than an
indirection layer invented to save them, and per-controller helper methods are exactly what caused the
two sibling controllers above to drift into incompatible shapes in the first place.

## 4. Ransack first, Query object only for real business logic

Every controller with a searchable `index` already includes `RansackSearchable`
(`app/controllers/concerns/ransack_searchable.rb`) and calls `apply_ransack_search(scope,
default_sort:)`. If the field you need to filter on is already (or can be) listed in the model's
`ransackable_attributes`, that's the filter — `q[field_in][]=...`/`q[field_eq]=...` — with zero
controller code. See [`docs/api/search-filter-sort-pagination.md`](../api/search-filter-sort-pagination.md)
for the full frontend contract.

Write a Query object only when there's real business logic a plain Ransack predicate can't express:

- **A mandatory scope that isn't a client-toggleable filter.** `EntityUsers::IndividualFishermenQuery`
  (`app/queries/entity_users/individual_fishermen_query.rb`) always constrains to individual
  registration types — that's what defines the endpoint, not something the client opts into.
- **Cross-column value translation.** `Admin::AccountsQuery`
  (`app/queries/admin/accounts_query.rb`) filters by a public "active"/"inactive" vocabulary that maps
  to *different* columns with *different* values depending on account category
  (`fisherman_status: "active"/"suspended"` vs `status: "active"/"inactive"`) — no single Ransack
  predicate can express that.

Query object convention: `self.call(scope:, ...)` with keyword arguments, `private_class_method` for
internal steps, returns an ActiveRecord relation (or a plain Hash when the caller needs a finished
aggregate, not a further-composable relation — see `app/queries/fisherman/dashboard/summary_query.rb`
for that shape). No authorization, no response formatting, no side effects. Prefer Rails' own relation
combinators (`#or`, `#merge`) over a raw SQL string with positional `?` binds when the same result is
reachable with plain `.where` hashes — `Admin::AccountsQuery`'s "no category given" branch is
`fisherman_scope(...).or(jetty_manager_scope(...))`, not a hand-built `OR` string.

## 5. Persisted aggregates: model callback vs explicit service call

Two real examples in this codebase, deliberately different:

- **`app/services/company_profiles/sync_worker_quota.rb`** — recomputes `company_profile.worker_quota`
  by summing `companies_vessels.max_crew`, called explicitly from
  `app/services/companies_vessels/create.rb`, `update.rb`, and inline from the discard action in
  `vessels_controller.rb`. Three call sites, all in the same narrow feature area — small enough that a
  human can be trusted not to add a fourth vessel-mutation path without remembering the sync call.
- **`app/models/concerns/user/entity_user_counting.rb`** — maintains
  `company_profile.entity_user_count` via `after_create`/`after_discard`/`after_undiscard` callbacks
  on `User`. Users that affect this count are created or discarded from at least six different places
  across the codebase (three registration/provisioning services, three discard call sites across admin
  and fisherman controllers), with more likely to be added as registration flows grow. Threading an
  explicit sync call through six-plus scattered sites risks silent drift the moment one new path
  forgets it — worse than the live correlated subquery this replaced. The callback can't be forgotten
  because it isn't called from the mutation site at all; it fires automatically whenever `User`'s
  kept-state changes, using `Discard::Model`'s own `after_discard`/`after_undiscard` hooks (already a
  dependency, already included on `User`).

Rule of thumb: **one or two mutation sites in one feature area → explicit service call.** **Three or
more, or spread across features/audiences → model callback.** Either way, the aggregate itself is a
persisted column, backfilled once via a migration — not a live correlated subquery once the row is
mutated from more than a couple of places.

## 6. Extending this doc

When a new deviation from this shape gets fixed, add it here rather than only fixing the code —
the value of this doc is that it stays the accurate, current answer to "how do we do X here," not a
one-time cleanup log.
