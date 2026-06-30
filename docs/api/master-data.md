# Master Data API

CRUD endpoints for reference/lookup data managed by DoFi Officers. All endpoints require JWT authentication and a role with the corresponding permission.

Base path: `/api/v1/master_data`

---

## Resources overview

| Resource | Base URL | Permission prefix | reference_id format |
|---|---|---|---|
| Port | `/api/v1/master_data/ports` | `ports` | `PT-NNN` (auto) |
| Zone | `/api/v1/master_data/zones` | `zones` | — (name is identifier) |
| Fishing Gear | `/api/v1/master_data/fishing_gears` | `fishing_gears` | `FG-NNN` (auto) |
| Nationality | `/api/v1/master_data/nationalities` | `nationalities` | `NT-NNN` (auto) |
| Position | `/api/v1/master_data/positions` | `positions` | `POS-NNN` (auto) |
| Reason | `/api/v1/master_data/reasons` | `reasons` | `REA-NNN` (auto) |

`reference_id` fields are auto-generated on create — do not send them in request bodies.

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
| `reference_id` | string | Auto-generated `PT-NNN` |
| `port_name` | string | Required |
| `latitude` | decimal | Optional |
| `longitude` | decimal | Optional |
| `created_at` | datetime | |
| `updated_at` | datetime | |

### Endpoints

```
GET    /api/v1/master_data/ports           # index (paginated)
GET    /api/v1/master_data/ports/:id       # show
POST   /api/v1/master_data/ports           # create
PATCH  /api/v1/master_data/ports/:id       # update
DELETE /api/v1/master_data/ports/:id       # destroy
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
| `reference_id` | string | Auto-generated `FG-NNN` |
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
| `reference_id` | string | Auto-generated `NT-NNN` |
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
| `reference_id` | string | Auto-generated `POS-NNN` |
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
| `reference_id` | string | Auto-generated `REA-NNN` |
| `name` | string | Required |
| `discarded_at` | datetime | Set on soft-delete; null = active |
| `created_at` | datetime | |
| `updated_at` | datetime | |

### Endpoints

```
GET    /api/v1/master_data/reasons           # index (paginated)
GET    /api/v1/master_data/reasons/:id       # show
POST   /api/v1/master_data/reasons           # create
PATCH  /api/v1/master_data/reasons/:id       # update
DELETE /api/v1/master_data/reasons/:id       # soft-delete (sets discarded_at)
```

### Create request body

```json
{
  "reason": {
    "name": "Engine malfunction"
  }
}
```
