# Master Data API

CRUD endpoints for reference/lookup data managed by DoFi Officers. All endpoints require JWT authentication and a role with the corresponding permission.

Base path: `/api/v1/admin/master_data` for full CRUD (DoFi Officer/Jetty Manager). Ports, Zones, and
Fishing Gears are also dual-mounted read-only (`index`/`show` only) at `/api/v1/fisherman/master_data`
for the Fisherman app — same controllers, same records, just a narrower action set and a different
`RequireAudience` prefix (see `config/routes.rb`). Nationalities, Positions, and Reasons have no
Fisherman-side route at all.

---

## Resources overview

| Resource | Admin Base URL (full CRUD) | Fisherman Base URL (read-only) | Permission prefix |
|---|---|---|---|
| Port | `/api/v1/admin/master_data/ports` | `/api/v1/fisherman/master_data/ports` | `ports` |
| Zone | `/api/v1/admin/master_data/zones` | `/api/v1/fisherman/master_data/zones` | `zones` |
| Fishing Gear | `/api/v1/admin/master_data/fishing_gears` | `/api/v1/fisherman/master_data/fishing_gears` | `fishing_gears` |
| Nationality | `/api/v1/admin/master_data/nationalities` | — (admin only) | `nationalities` |
| Position | `/api/v1/admin/master_data/positions` | — (admin only) | `positions` |
| Reason | `/api/v1/admin/master_data/reasons` | — (admin only) | `reasons` |

These resources previously exposed an auto-generated `reference_id` display code (`"PT-NNN"`,
`"FG-NNN"`, ...); it was removed as inert legacy (see `docs/registration/business-flow.md` §9). Identify/search
records by `name` (or `port_name`/`local_name` where the resource has no generic `name` field —
see each resource's Fields table below) instead.

---

## Common response shape

All endpoints follow the standard envelope:

```json
{ "status": "success", "data": { ... } }
{ "status": "success", "data": [ ... ], "meta": { "page": 1, "pages": 5, "count": 42, "limit": 25 } }
{ "status": "fail", "errors": ["Name can't be blank"] }
```

---

## Port

### Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `port_name` | string | Required |
| `latitude` | decimal | Optional |
| `longitude` | decimal | Optional |
| `created_at` | datetime | |
| `updated_at` | datetime | |

### Endpoints

```
GET    /api/v1/admin/master_data/ports           # index (paginated)
GET    /api/v1/admin/master_data/ports/:id       # show
POST   /api/v1/admin/master_data/ports           # create
PATCH  /api/v1/admin/master_data/ports/:id       # update
DELETE /api/v1/admin/master_data/ports/:id       # destroy

GET    /api/v1/fisherman/master_data/ports       # index (paginated), read-only
GET    /api/v1/fisherman/master_data/ports/:id   # show, read-only
```

### Create request body

```json
{
  "port": {
    "port_name": "Serasa Port",
    "latitude": "5.034722",
    "longitude": "115.072222"
  }
}
```

---

## Zone

### Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `name` | string | Required — the zone label (e.g. "Zone 2 Keatas") |
| `zone_type` | string | Optional (e.g. "Inshore", "Offshore", "Deep Sea") |
| `start_range` | string | Required — range start (e.g. "3 Nm") |
| `end_range` | string | Required — range end (e.g. "20 Nm") |
| `created_at` | datetime | |
| `updated_at` | datetime | |

### Create request body

```json
{
  "zone": {
    "name": "Zone 1A & Keatas",
    "zone_type": "Inshore",
    "start_range": "0 Nm",
    "end_range": "3 Nm"
  }
}
```

---

## Fishing Gear

### Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `local_name` | string | Required — local/Malay name |
| `name` | string | Required — English name |
| `gear_type` | string | Required (e.g. "Net", "Line", "Trawl") |
| `unit` | string | Required — `Meter` or `Quantity` |
| `size` | decimal | Optional — numeric size |
| `fee` | decimal | Required — licensing fee in BND |
| `created_at` | datetime | |
| `updated_at` | datetime | |

### Create request body

```json
{
  "fishing_gear": {
    "local_name": "Rawai",
    "name": "Longline",
    "gear_type": "Line",
    "unit": "Meter",
    "size": "50",
    "fee": "10.00"
  }
}
```

---

## Nationality

### Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `name` | string | Required, unique |
| `code` | string | Optional — ISO 3166-1 alpha-2 (e.g. "BN", "MY") |
| `created_at` | datetime | |
| `updated_at` | datetime | |

### Create request body

```json
{
  "nationality": {
    "name": "Bruneian",
    "code": "BN"
  }
}
```

---

## Position

### Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `name` | string | Required, unique |
| `category` | string | Required — `Fisherman`, `Jetty Manager`, or `DoFi Officer` |
| `created_at` | datetime | |
| `updated_at` | datetime | |

### Create request body

```json
{
  "position": {
    "name": "Crew",
    "category": "Fisherman"
  }
}
```

---

## Reason (Skip Reason)

Used when a vessel returns early or skips capture reporting.

### Fields

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `name` | string | Required |
| `discarded_at` | datetime | Set on soft-delete; null = active |
| `created_at` | datetime | |
| `updated_at` | datetime | |

### Endpoints

```
GET    /api/v1/admin/master_data/reasons           # index (paginated)
GET    /api/v1/admin/master_data/reasons/:id       # show
POST   /api/v1/admin/master_data/reasons           # create
PATCH  /api/v1/admin/master_data/reasons/:id       # update
DELETE /api/v1/admin/master_data/reasons/:id       # soft-delete (sets discarded_at)
```

### Create request body

```json
{
  "reason": {
    "name": "Engine malfunction"
  }
}
```
