# Plan: 1 bucket private, semua file lewat API, tanpa public endpoint MinIO

Branch kerja: `fix/vessel-image-urls-and-attachment-policy` (atau branch baru dari `main` kalau mau dipisah dari fix vessel).
Status: **2026-10-27: inti rencana dikerjakan di branch `feat/relay-attachments` (§4.1, 4.2, 4.4, 4.6, tes; semua hijau, belum di-commit/rilis).** Belum: §4.3 (rake sudah diarahkan ke service default, belum dijalankan), §4.5, §4.7, dokumen MINIO.md penuh, dan perubahan FE. Rencana awal (2026-10-05): belum ada kode yang diubah.

> Dokumen ini rencana kerja, bukan sumber kebenaran. Setelah implementasi selesai, [MINIO.md](MINIO.md) yang
> diperbarui (§6 di bawah) menjadi acuan, dan file ini boleh diarsipkan atau dihapus.
> Bahan diskusi dengan tim frontend: [FE-DISCUSSION-FILE-DELIVERY.md](FE-DISCUSSION-FILE-DELIVERY.md).

---

## 1. Keputusan

| Pertanyaan | Jawaban |
|---|---|
| Apakah MinIO perlu public endpoint? | **Tidak**, kalau API yang membawa bytes-nya (relay). Public endpoint hanya konsekuensi dari desain `302 redirect` yang sekarang. |
| Apakah 1 bucket private aman dari sisi development? | **Ya.** Lebih sederhana dan lebih konservatif. Bucket publik hanya ada supaya Rails tidak ada di jalur gambar Dictionary; setelah semua file di-relay, keuntungan itu hilang. |
| Perlu dikerjakan juga? | **Ya, menutup route bawaan Active Storage yang tidak ber-auth** (lihat §2.3). Ini berlaku apa pun pilihan bucket-nya. |

Dua keputusan user yang sudah diambil: (1) semua file lewat Rails, hapus public endpoint; (2) cukup 1 bucket private
karena target deploy adalah server Gov Brunei.

---

## 2. Latar belakang dan temuan (semua dari membaca kode, belum dijalankan di staging)

### 2.1 Kenapa sekarang butuh public endpoint

- [attachments_controller.rb:31](../../app/controllers/api/v1/attachments_controller.rb#L31) →
  `redirect_to presigned_url(blob), status: :found`. URL itu ditandatangani terhadap `MINIO_PUBLIC_ENDPOINT`
  (`app/services/attachments/public_url.rb`). Setelah `302`, **browser user sendiri** yang mengambil file dari MinIO.
- `Dictionary#image_url` (`app/blueprints/dictionary_blueprint.rb` → `Attachments::AssetUrl`) mengembalikan URL MinIO
  langsung (juga `MINIO_PUBLIC_ENDPOINT`).
- Frontend = JS di browser user, bukan di server. Browser tidak bisa me-resolve `minio:9000` (nama Docker) atau
  `127.0.0.1:9002` (loopback server). Itulah bug yang diperbaiki commit `e987c32`.
- "Private" pada nama bucket = tidak ada akses anonim. Itu **bukan** berarti tidak bisa dijangkau browser.
  Dua hal berbeda yang gampang tertukar.

### 2.2 Kenapa tidak lagi butuh bucket publik

- `docs/minio/MINIO-WHY-TWO-BUCKETS.md` menjelaskan bucket publik dibuat untuk satu hal: Rails tidak dilibatkan untuk
  konten yang selalu boleh dilihat (hanya `Dictionary`). Bagian "When is a single private bucket enough?" di dokumen
  yang sama menyebut sistem HR/rumah sakit/keuangan cukup 1 bucket private.
- Kalau API me-relay semua file, "Rails dilewati" tidak ada lagi, jadi bucket publik tinggal biaya: 3 env var,
  1 credential, 1 policy, anonymous `GetObject`, keputusan "pilih tier" tiap model baru, dan satu kelas bug
  (`service_name` tidak cocok dengan `has_one_attached`, lihat `MINIO.md` §9).
- Ukuran file kecil: gambar kapal 2 MB (`CompaniesVessel::IMAGE_MAX_SIZE`), Dictionary 5 MB
  (`Dictionary::MAX_IMAGE_SIZE`), dokumen PDF 10 MB (`CompaniesDocument::MAX_FILE_SIZE`). Relay masuk akal.

### 2.3 Lubang yang sudah ada (harus ditutup)

`rails routes` (env test) menunjukkan route bawaan Active Storage digambar di app ini:

- `GET /rails/active_storage/blobs/proxy/:signed_id/*filename` → `ActiveStorage::Blobs::ProxyController`
- `GET /rails/active_storage/blobs/redirect/:signed_id/*filename` dan `.../blobs/:signed_id/*filename`
- `GET /rails/active_storage/representations/...`
- `POST /rails/active_storage/direct_uploads`

Dari source gem (`activestorage-8.1.3.1`): semua inherit `ActiveStorage::BaseController < ActionController::Base`,
tanpa autentikasi (`set_blob` hanya `find_signed!`). `Blob#signed_id` default **tidak kedaluwarsa**
(`expires_in: nil`). Padahal `signed_id` itu persis yang kita kirim ke user yang berhak
(`api_v1_attachment_path(blob.signed_id)`).

Akibatnya: siapa pun yang memegang satu `signed_id` file private (dari log, riwayat browser, URL yang dibagikan) bisa
mengambil file itu lewat route proxy **tanpa JWT, tanpa Pundit, tanpa audit log**, permanen. Ini membatalkan klaim
di `MINIO.md` §3 bahwa "authorization re-checked every request". Belum diuji di staging; berdasar route table dan
kode gem. Perbaikan: `config.active_storage.draw_routes = false` di production.

### 2.4 Cek policy untuk gambar Dictionary lewat endpoint ber-auth

`AttachmentsController` memanggil `authorize attachment.record, :show?` → `DictionaryPolicy#show?`.

- `DictionaryPolicy` meng-include `FishermanReadable` → fisherman selalu `show?` true.
- Officer/Jetty Manager butuh `dictionaries.view` (`Permission::Catalog`: `dofi_officer: list view create update delete`).
- Konsekuensi: role dengan `dictionaries.list` tapi tanpa `dictionaries.view` akan 403 untuk gambar (dulu bisa karena
  URL publik). Tidak diubah di plan ini; dicatat di risiko.

---

## 3. Arsitektur sebelum vs sesudah

Sebelum:

```
FE ──GET /api/v1/attachments/:sid (JWT)──▶ Rails: Pundit ──302──▶ FE ──GET presigned (MINIO_PUBLIC_ENDPOINT)──▶ nginx ──▶ MinIO
FE ──GET image_url (anonim, MINIO_PUBLIC_ENDPOINT)────────────────────────────────────────────────────────────▶ nginx ──▶ MinIO   (Dictionary)
```

Sesudah:

```
FE ──GET /api/v1/attachments/:sid (JWT)──▶ Rails: Pundit + log ──blob.download (http://minio:9000, internal)──▶ MinIO
                                          └──200 + bytes──▶ FE
```

MinIO hanya bisa dijangkau `api`/`jobs` lewat jaringan Docker. Tidak ada vhost nginx, DNS, sertifikat, CORS MinIO,
mixed content, atau masalah `Host`/SigV4 untuk MinIO.

### 3.1 Dampak ke frontend

Ringkasan di bawah; detail kontrak, contoh kode, urutan rilis, dan pertanyaan untuk FE ada di
[FE-DISCUSSION-FILE-DELIVERY.md](FE-DISCUSSION-FILE-DELIVERY.md) (bahan diskusi dengan tim FE). Repo FE tidak ada di
mesin ini, jadi ini berdasarkan kontrak API, bukan kode FE.

| Bagian | Berubah di FE? |
|---|---|
| `image_urls` gambar kapal, `document_url` dokumen | **Biasanya tidak.** URL dan header `Authorization` sama; respons `302` → `200` + bytes. Hanya bermasalah bila FE menangani redirect secara manual |
| `image_url` Dictionary (admin index/show/create/update, `fisherman/dictionaries`) | **Ya.** URL absolut publik → path relatif `/api/v1/attachments/:sid` yang butuh JWT; tidak bisa lagi jadi `<img src>` telanjang |
| `image_url` Dictionary di offline bundle (`fisherman/manifests/:id/offline_bundle`, `Manifests::OfflineBundle`) | **Ya, paling berisiko.** Pre-cache gambar kini harus ber-auth dan bisa memicu ratusan request sekaligus (§9) |
| Login, JWT, permission, upload, endpoint lain | Tidak |

---

## 4. Langkah implementasi

Urutan: kode → test → dokumen → verifikasi lokal → deploy staging → cleanup. Tiap blok kode ikut aturan repo
([CLAUDE.md](../../CLAUDE.md)): action controller = `authorize → satu panggilan → render inline`,
tanpa helper render, tanpa service baru untuk hal yang tidak perlu.

### 4.1 `AttachmentsController#show` — relay, bukan redirect

File: `app/controllers/api/v1/attachments_controller.rb`

```ruby
rescue_from ActiveStorage::FileNotFoundError, with: :render_not_found   # di samping rescue_from InvalidSignature

def show
  blob = ActiveStorage::Blob.find_signed!(params.expect(:signed_id))
  attachment = attachment_for(blob)

  authorize attachment.record, :show?, policy_class: POLICY_CLASS_BY_RECORD_TYPE[attachment.record_type]
  log_attachment_access(attachment, granted: true)

  response.headers["Cache-Control"] = "private, max-age=0"
  send_data blob.download, type: blob.content_type_for_serving,
                           disposition: blob.forced_disposition_for_serving || disposition,
                           filename: blob.filename.sanitized
rescue Pundit::NotAuthorizedError
  ...tidak berubah...
end
```

- Hapus method `presigned_url` dan komentar panjang Brakeman-nya (tidak ada redirect lagi).
- **`send_data`, bukan `send_blob_stream`:** `send_blob_stream` meng-include `ActionController::Live`, yang menjalankan
  action di thread lain dan terkenal bentrok dengan Devise/Warden (`throw :warden`). Dengan batas 10 MB,
  `blob.download` (di memori) cukup.
- **`content_type_for_serving` + `forced_disposition_for_serving` wajib:** bytes sekarang keluar dari origin API, jadi
  tipe berbahaya (HTML/SVG/XML/JS) harus dipaksa jadi `application/octet-stream` + `attachment`. Rails sudah punya
  daftarnya (`ActiveStorage.content_types_to_serve_as_binary`, `content_types_allowed_inline`).
- `Cache-Control: private, max-age=0` dan log akses tetap, supaya otorisasi dicek setiap request.
- **Conditional GET (masuk rencana, bukan opsional):** setelah `authorize`, panggil
  `return unless stale?(etag: blob.checksum)` sebelum `send_data`. Kunjungan ulang dan re-sync offline mendapat `304`
  tanpa bytes, otorisasi tetap dicek tiap request. Alasannya offline bundle (§3.1): FE bisa meminta ratusan gambar.
  Efek: header `Cache-Control` menjadi `max-age=0, private, must-revalidate`; sesuaikan tes (§5).
- **CORS:** di `config/initializers/cors.rb` ubah `expose: %w[Authorization]` menjadi
  `expose: %w[Authorization Content-Disposition]` supaya FE bisa membaca nama file dari respons API (dulu respons
  datang dari MinIO). `Content-Type`/`Content-Length` sudah termasuk header yang boleh dibaca lintas origin.

### 4.2 Dictionary pindah ke tier private

- `app/models/dictionary.rb`: `has_one_attached :image` (hapus `service:` dan komentar "downloads bypass Rails").
- `app/services/dictionaries/create.rb` dan `update.rb`: `uploaded_blob_for` tidak lagi memberi `service_name`
  (hapus juga komentar "which of the two buckets").
- `app/services/attachments/upload_from_param.rb`: hapus kwarg `service_name:` (sekarang semua pemanggil memakai default);
  update 4 pemanggil: `dictionaries/create.rb`, `dictionaries/update.rb`, `companies_documents/create.rb`,
  `companies_documents/update.rb` (dua yang terakhir sekarang `service_name: nil`).
- `app/blueprints/dictionary_blueprint.rb`:

  ```ruby
  field :image_url do |dictionary|
    next nil unless dictionary.image.attached?

    Rails.application.routes.url_helpers.api_v1_attachment_path(dictionary.image.blob.signed_id)
  end
  ```
  Perbarui komentarnya (sekarang sama dengan `CompaniesVesselBlueprint#image_urls`).
- Hapus `config.x.active_storage_public_service` dari `config/environments/{production,development,test}.rb`.
- Hapus file: `app/services/attachments/asset_url.rb`, `app/services/attachments/public_url.rb`,
  `test/services/attachments/asset_url_test.rb`, `test/services/attachments/public_url_test.rb`.
  Hapus `RecordingServiceDouble` dan `stub_fetched_service` dari `test/test_helper.rb` kalau tidak ada pemakai lain
  (`grep -rn "RecordingServiceDouble\|stub_fetched_service" test`).

### 4.3 Gambar Dictionary yang sudah ada

Blob lama (di bucket `minio_assets`, atau Cloudinary) tetap terbaca tanpa perubahan: Active Storage memilih service dari
`active_storage_blobs.service_name` milik blob. Syaratnya blok `minio_assets` dan credential `MINIO_ASSETS_*` masih ada.

- `lib/tasks/dictionaries.rake` (`dictionaries:migrate_images_to_minio`): ganti target dari
  `config.x.active_storage_public_service` ke service default (`Rails.application.config.active_storage.service`).
  Perbarui `desc` dan komentarnya. Task ini sudah idempotent dan punya `DRY_RUN=1`.
- Jalankan di staging: dry run dulu, lalu sungguhan, lalu pastikan satu gambar Dictionary masih tampil.
- Setelah task melaporkan 0 sisa: PR lanjutan menghapus blok `minio_assets` dari `storage.yml`, env `MINIO_ASSETS_*`,
  bagian public-bucket di `mc-init.sh`, dan bucket publik di server (`mc anonymous set none` lalu hapus bucket).
- Production Gov: deploy baru, tidak ada data lama; langsung 1 bucket, tidak perlu `MINIO_ASSETS_*`.

### 4.4 Tutup route Active Storage yang tidak ber-auth

- `config/environments/production.rb`: `config.active_storage.draw_routes = false` + komentar alasannya
  (rujuk §2.3 dokumen ini / `MINIO.md`).
- Hanya production: dev/test memakai Disk service yang butuh `rails_disk_service`.
- Sebelum itu: `grep -rn "rails_blob\|rails_storage\|rails_representation\|url_for" app lib` untuk memastikan tidak ada
  yang memakai route tersebut. Kalau ada, pindahkan ke `api_v1_attachment_path`.
- Efek samping yang diinginkan: `direct_uploads` (pembuatan blob tanpa auth) ikut hilang.

### 4.5 `config/storage.yml`

- Hapus `minio_public` dan `minio_assets_public`.
- `minio` tetap (endpoint internal, bucket private). `minio_assets` tetap **sementara**, diberi komentar
  "legacy: hanya untuk membaca blob lama sampai migrasi §4.3 selesai".
- Rapikan komentar di atasnya (tidak ada lagi "signing endpoint" dan "browser-reachable").

### 4.6 Rack::Attack

File: `config/initializers/rack_attack.rb`

- Sekarang `req/ip` = 300 request / 5 menit / IP. Halaman daftar Dictionary memuat N thumbnail, masing-masing satu
  request ber-auth lewat Rails; beberapa officer di satu NAT kantor bisa terkena 429.
- Kecualikan path `/api/v1/attachments/` dari `req/ip` dan beri throttle sendiri `attachments/ip` dengan limit lebih
  tinggi (usul 1500 / 5 menit; angka ini keputusan operasional, bisa disesuaikan).
- Request tanpa/ber-JWT salah tetap ditolak murah (verifikasi tanda tangan JWT, tanpa query DB).

### 4.7 `mc-init.sh`, compose, `.env.example`

- `docker/mc-init.sh`: bungkus seluruh bagian "Public assets bucket" (mb, policy, user, attach/detach,
  `anonymous set-json`) dengan `if [ -n "${MINIO_ASSETS_BUCKET:-}" ]; then ... fi` supaya environment baru tidak
  perlu `MINIO_ASSETS_*`. Bagian private bucket tidak berubah.
- `docker-compose.staging.yml`, `docker-compose.production.yml`, `docker-compose.production.local.yml`:
  `MINIO_ASSETS_*` tetap diteruskan (kosong kalau tidak di-set); hapus komentar tentang `MINIO_PUBLIC_ENDPOINT`
  dan "reverse proxy ... presigned image URLs reachable from a browser".
- `.env.example`: hapus `MINIO_PUBLIC_ENDPOINT`; tandai `MINIO_ASSETS_*` sebagai legacy/opsional; koreksi komentar
  di atas `MINIO_BUCKET` ("Api::V1::AttachmentsController" tetap benar, tapi bukan lagi redirect).
- Workflow CI/CD (`.github/workflows/cd-*.yml`) tidak menyebut `MINIO_*`; env datang dari `.env` server, jadi tidak diubah.

---

## 5. Test

### Diubah
`test/controllers/api/v1/attachments_controller_test.rb`
- "redirects to a freshly signed storage URL…" → `assert_response :ok`; body = bytes blob; `Content-Type`;
  `Content-Disposition` inline; `Cache-Control` berisi `max-age=0`, `private`, `must-revalidate`; ada `ETag`;
  tidak ada header `Location`.
- Request ulang dengan `If-None-Match` = ETag → `304`, body kosong; user tanpa izin yang mengirim `If-None-Match`
  yang sama tetap `403` (bukti otorisasi mendahului conditional GET).
- Respons CORS dari origin FE mengekspos `Content-Disposition` (cek `Access-Control-Expose-Headers`).
- `Manifests::OfflineBundle`: `dictionaries[].image_url` berupa path attachments (tes bundle yang sudah ada diperluas).
- Vessel image, company document, fisherman own-company: `:found` → `:ok`. Kasus 401, 403, 404 (signed_id rusak) tetap.

`test/controllers/api/v1/admin/dictionaries_controller_test.rb`
- Tes "image_url is a direct public-bucket URL" → "image_url is the authenticated attachments path"
  (`assert_equal "/api/v1/attachments/#{blob.signed_id}", image_url`). Tes "nil when no image" tetap.

### Ditambah
- Blob HTML/SVG (`text/html`, `image/svg+xml`) dilayani sebagai `application/octet-stream` + `attachment`.
- Blob yang file-nya hilang di storage → 404 (bukan 500), lewat `ActiveStorage::FileNotFoundError`.
- Dictionary image: fisherman → 200; officer dengan `dictionaries.view` → 200; officer hanya `dictionaries.list` → 403
  (mendokumentasikan perilaku di §2.4).
- `fisherman/dictionaries` index memuat `image_url` berupa path attachments.
- Test pembersihan: `purge_unattached_blobs_job_test.rb` memakai dictionary image di service `:test`; pastikan tetap hijau.

### Dihapus
`asset_url_test.rb`, `public_url_test.rb` (kelasnya dihapus).

### Tidak bisa dites di unit/integration test
Route Active Storage tidak digambar di production: dicek lewat route table (§6.2), karena route ditetapkan saat boot per env.

---

## 6. Dokumen

Prinsip (memory "doc density"): jelaskan dan beri link, jangan salin snapshot panjang.

| File | Perubahan |
|---|---|
| `docs/minio/MINIO.md` | §1-2: hapus pembagian endpoint internal/publik dan tabel dua bucket → satu bucket private; §2 diagram staging/production tanpa node PROXY; §3 hapus alur "public bucket", ganti alur relay (diagram sequence: FE → AttachmentsController → Pundit → `blob.download` → MinIO → 200); §4 hapus "Step 0 pilih tier" dan blok Blueprint publik; §5 hapus `MINIO_PUBLIC_ENDPOINT`, tandai `MINIO_ASSETS_*` legacy; §6 hapus kalimat "set up a reverse proxy…"; §9 hapus baris DNS_PROBE/`SignatureDoesNotMatch`/proxy, tambah baris "gambar 404 setelah deploy"; §10 hapus "proxy plain HTTP"; tambahkan catatan `draw_routes = false` |
| `docs/minio/MINIO-WHY-TWO-BUCKETS.md` | Banner "Superseded: semua file kini di-relay, 1 bucket"; reasoning dipertahankan sebagai sejarah |
| `docs/minio/MINIO-TWO-BUCKET-SETUP.md` | Banner superseded; bagian migrasi tetap berguna untuk memindahkan blob lama |
| `docs/minio/MINIO-PUBLIC-PROXY-SETUP.md` | Banner "Superseded — MinIO tidak lagi diekspos" |
| `docs/minio/MINIO-HTTPS-PUBLIC-ENDPOINT.md` (untracked) | Banner superseded; jangan dihapus (milik user) |
| `docs/minio/MINIO-FAQ.md` | Perbarui jawaban "Do image URLs have to go through the reverse proxy?" → tidak lagi ada proxy |
| `docs/incidents/POSTMORTEM-2026-07-27-minio-presigned-url.md` | Tambah satu baris update: akar masalah dihilangkan dengan relay (tidak ada endpoint publik lagi) |
| `README.md` baris ~91 dan ~257-260 | Ganti "two buckets…" dan daftar link doc; perbaiki deskripsi tutorial proxy |
| `postman/DoFi-Backend.postman_collection.json` | Deskripsi folder vessel (~L6819) dan dokumen (~L7217): "answers 302…" → "answers 200 with the file bytes"; nama tes ~L7311 "private attachment redirect" → "private attachment endpoint". Postman collection tidak perlu env baru |
| `AGENTS.md` / `CLAUDE.md` | Tidak berubah (aturan tidak berubah; kalimat Stack hanya menyebut MinIO) |

---

## 7. Verifikasi

### 7.1 Otomatis (definition of done repo)
```bash
bin/rbac-lint
bin/rubocop
bin/rails test
bin/brakeman          # hapus peringatan redirect lama; send_data tidak boleh memunculkan temuan baru
```

### 7.2 Route table production
```bash
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails routes | grep active_storage   # harus kosong
RAILS_ENV=test bin/rails routes | grep active_storage                                # masih ada (Disk)
```

### 7.3 Stack lokal image production (MinIO sungguhan, tanpa public endpoint)
`docker-compose.production.local.yml` dengan `.env.production` **tanpa** `MINIO_PUBLIC_ENDPOINT` dan **tanpa**
`MINIO_ASSETS_*` (bukti bahwa 1 bucket cukup; butuh `docker login ghcr.io`, lihat `MINIO.md` §6):
1. `docker compose ... run --rm mc-init` selesai tanpa error (bagian publik dilewati).
2. Upload vessel image, PDF dokumen, dan Dictionary image.
3. `GET /api/v1/attachments/:sid` dengan JWT → 200, byte-nya identik; tanpa JWT → 401; user tanpa izin → 403.
4. `GET /rails/active_storage/blobs/proxy/<sid>/x.png` tanpa JWT → 404.
5. Hapus Dictionary → `ActiveStorage::PurgeJob` berhasil (cek `s3:ListBucket` masih ada, lihat `MINIO.md` §9 baris terakhir).

### 7.4 Staging
1. Deploy; `.env` staging: hapus `MINIO_PUBLIC_ENDPOINT`; `docker compose up -d --force-recreate api jobs`
   (`restart` biasa tidak membaca ulang `env_file`).
2. `bin/rails dictionaries:migrate_images_to_minio DRY_RUN=1`, lalu tanpa `DRY_RUN`.
3. Dari frontend HTTPS: gambar kapal, dokumen PDF, dan gambar Dictionary tampil; Console tanpa mixed content/CORS.
4. `curl -i https://api-dofi.datablu.asia/rails/active_storage/blobs/proxy/<sid>/x` → 404.
5. Ops: hapus vhost nginx `dofi-minio` di port 9010 dan tutup port tersebut.

---

## 8. Rollback

Kode: revert commit + redeploy. Data MinIO tidak disentuh oleh perubahan kode; blob Dictionary yang sudah dimigrasi ke
bucket private tetap valid dengan kode lama selama service `minio` ada (kode lama membaca `blob.service_name`).
`MINIO_PUBLIC_ENDPOINT` baru berfungsi lagi setelah commit ini di-revert, karena blok `minio_public` dihapus di sini.
Vhost nginx 9010 sebaiknya dihapus **setelah** staging stabil, supaya jalur rollback masih ada selama itu.

---

## 9. Risiko dan hal terbuka

1. **Frontend (tidak bisa diverifikasi dari repo ini):** lihat §3.1 dan
   [FE-DISCUSSION-FILE-DELIVERY.md](FE-DISCUSSION-FILE-DELIVERY.md). Perubahan FE terpusat di `image_url` Dictionary
   (daftar, detail, dan offline bundle). Catatan: URL lama (`http://…:9010`) kemungkinan sudah diblokir sebagai mixed
   content di FE HTTPS. **Rilis BE dan FE harus dikoordinasikan:** BE baru + FE lama membuat gambar Dictionary rusak
   (path relatif tanpa auth). Urutan aman: FE rilis dulu dengan loader ber-auth yang juga menerima URL absolut lama,
   baru BE.
2. **Beban:** tiap thumbnail = JWT decode + query user/permission + insert `api_request_logs` + baris log akses.
   Wajar untuk skala officer/nelayan. Mitigasi sudah masuk rencana: ETag/`304` (§4.1) dan limit `attachments/ip`
   terpisah (§4.6). Kalau masih berat: lewati log DB untuk route ini.
   **Offline bundle:** satu sinkronisasi bisa memicu ratusan request gambar ber-auth sekaligus (1 thread dari 3 Puma
   tiap request). Di sisi FE, ambil gambar secara lazy atau dengan konkurensi terbatas (±4). Jumlah Dictionary di
   staging belum dicek; ukur dulu (`Dictionary.count`) sebelum menentukan limit.
3. **Puma 3 thread** (`RAILS_MAX_THREADS` default): unduhan menahan satu thread selama transfer. Aman untuk ≤10 MB di
   belakang nginx yang mem-buffer respons; evaluasi lagi bila thumbnail banyak.
4. **Memori:** `blob.download` memuat seluruh file (≤10 MB per request).
5. **Izin Dictionary:** role `dictionaries.list` tanpa `dictionaries.view` kini melihat gambar rusak (§2.4).
6. **Isolasi credential hilang:** dengan 1 bucket, 1 credential mengakses semua. Wajar karena semua konten kini
   diperlakukan sensitif; credential hanya ada di `.env` container `api`/`jobs`.
7. **Konten dari origin API:** itu sebabnya `content_type_for_serving`/`forced_disposition_for_serving` dan header
   `X-Content-Type-Options: nosniff` (default Rails) penting; ada tes khusus.
8. **Belum terverifikasi:** eksploitasi nyata route proxy Active Storage di staging (hanya dibaca dari kode). Disarankan
   mengujinya sekali sebelum dan sesudah fix (`curl` tanpa JWT dengan `signed_id` milik dokumen).

## 10. Di luar cakupan

- Backup bucket MinIO (`mc mirror`), sudah dicatat di `MINIO.md` §10 sebagai tanggung jawab kita.
- Menghapus gem Cloudinary dan blok `cloudinary_*` (checklist cutover tersendiri di `MINIO.md` §8).
- Streaming/Range request, thumbnail/variant, CDN.
- Mengubah `AGENTS.md`/`CLAUDE.md`.

## 11. Checklist eksekusi

- [x] 4.1 `AttachmentsController` relay + rescue 404
- [x] 4.2 Dictionary ke tier private, hapus `AssetUrl`/`PublicUrl`/`active_storage_public_service`/`service_name:`
- [ ] 4.3 Retarget rake task migrasi
- [x] 4.4 `draw_routes = false` (setelah grep pemakai route)
- [ ] 4.5 `storage.yml` bersih
- [x] 4.6 Rack::Attack attachments
- [ ] 4.7 `mc-init.sh` kondisional, compose, `.env.example`
- [x] 5 Test diubah/ditambah/dihapus
- [ ] 6 Dokumen + Postman
- [ ] 7.1-7.2 hijau (rubocop, rbac-lint, brakeman, 765 tes, route production kosong); 7.3 stack lokal image production belum
- [ ] 7.4 Staging + ops (vhost 9010 dihapus)
- [ ] PR lanjutan: hapus `minio_assets`, `MINIO_ASSETS_*`, bucket publik setelah migrasi 0 sisa
