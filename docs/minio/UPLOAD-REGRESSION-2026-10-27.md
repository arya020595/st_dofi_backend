# Upload regression check after the file-relay change (2026-10-27)

> Historical record. It says what was checked, when, and with what result. It is not a how-to.
> Related: [`STORAGE-PROTOCOL-OPTIONS.md`](STORAGE-PROTOCOL-OPTIONS.md) (the decision),
> [`PLAN-SINGLE-PRIVATE-BUCKET.md`](PLAN-SINGLE-PRIVATE-BUCKET.md) (the design),
> [`FILE-ACCESS-SEQUENCE.md`](FILE-ACCESS-SEQUENCE.md) (the sequences).

## 1. Why this exists

The client does **not** allow any connection from a browser to the File Storage server. Browsers reach only the Web
server (the Frontend). The Frontend proxies `/api` to the Back End, and only the Back End talks to storage (S3 on
`9000`) and to the database (`5432`).

That rule is why the Back End no longer hands out presigned or public MinIO URLs. It sends the file bytes itself
(`GET /api/v1/attachments/:signed_id`, branch `feat/relay-attachments`), and every file URL in the JSON is now a
relative API path. The change also touched the **upload** path, so uploads were re-tested on their own.

## 2. What changed on the upload path

| Change | Why it could affect uploads |
|---|---|
| `Attachments::UploadFromParam.call(file)` lost its `service_name:` argument | Every caller changed with it |
| `Dictionary` uses `has_one_attached :image` on the default (private) service, not the public assets service | Dictionary images are now stored in a different bucket than before |
| Callers updated: `Dictionaries::Create`, `Dictionaries::Update`, `CompaniesDocuments::Create`, `CompaniesDocuments::Update` | Signature change |
| `AssetUrl`, `PublicUrl` and `config.x.active_storage_public_service` removed | Dead code left no reference behind |
| `config.active_storage.draw_routes = false` in production | Closes Active Storage's own routes, including direct uploads; the app uploads only through its own endpoints |

## 3. What was run

All on a developer machine with the project's PostgreSQL container, Active Storage on the `:test` disk service
(`DATABASE_PORT=5437 bin/rails test`).

1. The existing upload tests: vessel images, company documents (controller, services, model), Dictionary create,
   Dictionary controller, purge job. 32 runs, 0 failures.
2. New regression tests added, because the survey found gaps:
   - `test/controllers/api/v1/upload_round_trip_test.rb`: uploads through the real endpoints, then reads the file back
     through `GET /api/v1/attachments/...` with the JWT and compares the bytes and content type. Covers a Dictionary
     image on create, a Dictionary image replaced on update, a vessel image, and a company document (PDF). It also
     checks that a Dictionary image lands on the default storage service, and that a spoofed image (HTML sent as
     `image/png`) is rejected with no row and no attachment left behind.
   - `test/services/dictionaries/update_test.rb`: a new image is uploaded and attached; a spoofed image is rejected; a
     rejected upload leaves the record and its image untouched. (`Dictionaries::Update` had no test before.)
3. Full gates: `bin/rails test`, `bin/rubocop`, `bin/rbac-lint`, `bin/brakeman`.

## 4. Result

| Upload surface | Result |
|---|---|
| Vessel images (slots, replace, reject non-image) | Pass |
| Company documents (create, PDF only, replace) | Pass |
| Dictionary image, create (service and HTTP) | Pass |
| Dictionary image, update (service and HTTP) | Pass |
| Spoofed content type rejected, nothing persisted | Pass |
| Round trip: upload, then fetch the same bytes back via the API | Pass (Dictionary, vessel image, PDF) |
| Full suite | 776 runs, 3174 assertions, 0 failures, 3 errors, 30 skips |
| `bin/rubocop`, `bin/rbac-lint`, `bin/brakeman` | 0 offenses, passed, 0 warnings |

The 3 errors are `Rocbn::Seeding::SeederTest`, which needs the ROCBN MySQL on `localhost:3307`
(`docker compose up -d rocbn-mysql`). They fail on the missing MySQL connection and do not touch uploads.

## 5. Known limits

- **Not run against a real MinIO.** CI and these tests use the disk service. No MinIO image was available on the
  machine (the mirror in GHCR is private), so the real S3 write path was not exercised here. It was proven earlier on
  the client's servers (`db:prepare` uploaded 17 files over `9000`), before the relay change. Re-check with one upload
  and one view on the client's App server after the new image is deployed.
- Not tested on the client servers, and not tested through the Frontend proxy (its `/api` body-size limit must allow
  at least 12 MB).
- A storage outage during an upload (the `Aws::Errors::ServiceError` path in `Dictionaries::Update`) has no test
  because the repo has no stubbing library; the rescue code is unchanged.
