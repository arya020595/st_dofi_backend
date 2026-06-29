# Search, Filter, Sort & Pagination — Frontend Contract

This is the contract for `index` (list) endpoints that support searching, filtering, sorting, and
pagination. It currently covers:

| Endpoint | Paginated? | Auth required | Permission needed |
|---|---|---|---|
| `GET /api/v1/users` | Yes | Yes (JWT) | `dofi_officer_users.list` or `dofi_officer_users.view` |
| `GET /api/v1/roles` | Yes | Yes (JWT) | `roles.list` or `roles.view` |
| `GET /api/v1/permissions` | No (returns full filtered list) | Yes (JWT) | any authenticated user |

Send the JWT the same way as every other endpoint: `Authorization: Bearer <token>`.

---

## Request shape

All search/filter/sort params are nested under a single `q` object. Pagination params
(`page`, `limit`) are top-level, sibling to `q`.

```
GET /api/v1/users?q[name_cont]=alice&q[status_eq]=active&q[s]=created_at desc&page=2&limit=25
```

As a query string (URL-encoded):

```
/api/v1/users?q%5Bname_cont%5D=alice&q%5Bstatus_eq%5D=active&q%5Bs%5D=created_at+desc&page=2&limit=25
```

---

## Response shape

```json
{
  "status": "success",
  "data": [
    { "id": "5f1c...", "name": "Alice Tan", "email": "alice@example.com", "...": "..." }
  ],
  "meta": { "page": 2, "pages": 5, "count": 113, "limit": 25 }
}
```

- `meta` is only present on **paginated** endpoints (Users, Roles). `Permissions` has no `meta` key —
  it's small reference data and is always returned in full (filtered, not paginated).
- `data` is always an array, shaped per the resource's blueprint (`UserBlueprint`, `RoleBlueprint`,
  `PermissionBlueprint`).

---

## Pagination

| Param | Type | Default | Max | Notes |
|---|---|---|---|---|
| `page` | integer | `1` | — | 1-indexed |
| `limit` | integer | `25` | `100` | Values above 100 are silently clamped to 100 |

`meta` fields: `page` (current page), `pages` (total pages), `count` (total matching records, after
filtering), `limit` (effective page size).

---

## Sorting — `q[s]`

Format: `"<field> <direction>"`, direction is `asc` or `desc`.

```
# single sort
?q[s]=name asc

# multi-sort (array form) — sorts are applied in the order given
?q[s][]=role_id asc&q[s][]=created_at desc
```

If `q[s]` is omitted, the server falls back to a default sort per resource:

| Resource | Default sort |
|---|---|
| Users | `created_at desc` |
| Roles | `name asc` |
| Permissions | `code asc` |

---

## Filtering — `q[<field>_<predicate>]=<value>`

Combine any number of filters; they're AND-ed together by default.

| Predicate | Meaning | Example |
|---|---|---|
| `_eq` | equals | `q[status_eq]=active` |
| `_not_eq` | not equals | `q[status_not_eq]=inactive` |
| `_cont` | contains (case-insensitive) | `q[name_cont]=tan` |
| `_not_cont` | does not contain | `q[name_not_cont]=test` |
| `_start` | starts with | `q[email_start]=alice` |
| `_end` | ends with | `q[email_end]=@example.com` |
| `_gt` / `_gteq` | greater than / or equal | `q[created_at_gteq]=2026-01-01` |
| `_lt` / `_lteq` | less than / or equal | `q[created_at_lteq]=2026-06-01` |
| `_in` / `_not_in` | in / not in a list | `q[role_id_in][]=<uuid1>&q[role_id_in][]=<uuid2>` |
| `_null` / `_not_null` | is null / is not null | `q[discarded_at_null]=1` |
| `_present` / `_blank` | not null / null (alias of above) | `q[discarded_at_blank]=1` |

OR-ing two whitelisted fields is also available via the `_or_` combinator, e.g.:

```
q[name_or_email_cont]=alice
```

**Unknown or non-whitelisted fields are silently ignored** (not an error) — e.g. `q[encrypted_password_cont]=x`
has no effect and the request still returns `200 OK`. Only the fields listed below can be filtered or sorted.

---

## Per-resource reference

### Users — `GET /api/v1/users`

Filterable/sortable fields (`ransackable_attributes` on `User`):

`id`, `name`, `email`, `employee_id`, `status`, `preferred_locale`, `unit`, `position`, `role_id`,
`doft_registration_no`, `ic_number`, `registration_type`, `username_directory`, `discarded_at`,
`created_at`, `updated_at`

Notes:
- `id` and `role_id` are UUID strings — use `_eq`/`_in`, not `_cont`.
- `preferred_locale` is one of `en`, `ms`.
- Sensitive Devise columns (`encrypted_password`, `jti`, `reset_password_token`, etc.) are **not**
  whitelisted and can never be filtered/sorted on.
- Associations (e.g. filtering by `role.name`) are not enabled yet — only `role_id` (exact match) is
  available today.

Example — active users whose name or email contains "tan", sorted by name:

```
GET /api/v1/users?q[status_eq]=active&q[name_or_email_cont]=tan&q[s]=name asc
```

### Roles — `GET /api/v1/roles`

Filterable/sortable fields (`ransackable_attributes` on `Role`):

`id`, `reference_id`, `name`, `description`, `created_at`, `updated_at`

Example — roles created in the last 30 days:

```
GET /api/v1/roles?q[created_at_gteq]=2026-05-20&q[s]=created_at desc
```

### Permissions — `GET /api/v1/permissions`

Filterable/sortable fields (`ransackable_attributes` on `Permission`):

`id`, `code`, `name`, `created_at`, `updated_at`

This endpoint is **not paginated** — `page`/`limit` are ignored, `data` always contains every
permission matching the filter.

Example — permissions whose code contains "export":

```
GET /api/v1/permissions?q[code_cont]=export
```

---

## Frontend usage example

```js
async function fetchUsers({ name, status, page = 1, limit = 25, sort = "created_at desc" } = {}) {
  const params = new URLSearchParams();
  if (name) params.set("q[name_cont]", name);
  if (status) params.set("q[status_eq]", status);
  params.set("q[s]", sort);
  params.set("page", page);
  params.set("limit", limit);

  const res = await fetch(`/api/v1/users?${params}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  const { status: result, data, meta } = await res.json();
  return { users: data, pagination: meta };
}
```

For multi-sort, append the same key multiple times with the `[]` suffix
(`URLSearchParams` supports repeated keys natively):

```js
const params = new URLSearchParams();
params.append("q[s][]", "role_id asc");
params.append("q[s][]", "created_at desc");
```

---

## Adding a new searchable resource (backend note)

To extend this contract to a new `index` action:

1. Include `RansackSearchable` in the controller (`app/controllers/concerns/ransack_searchable.rb`).
2. Call `apply_ransack_search(policy_scope(Model), default_sort: "...")` and pass the result into `pagy`.
3. Define `ransackable_attributes` (and `ransackable_associations`, even if `[]`) on the model — Ransack
   raises an error if `ransackable_associations` isn't defined at all, even for attribute-only queries.
