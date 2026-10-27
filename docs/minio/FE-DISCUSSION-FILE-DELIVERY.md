# Bahan diskusi dengan Frontend: file dan gambar diambil lewat API

Status: **usulan, belum dirilis, belum ada kode yang diubah** (2026-10-05). Penulis: Backend.
Dokumen ini cukup dibaca sendiri oleh tim FE. Plan teknis Backend ada di
[PLAN-SINGLE-PRIVATE-BUCKET.md](PLAN-SINGLE-PRIVATE-BUCKET.md).

## 1. Ringkasan

- **Sekarang:** gambar kapal dan dokumen PDF diambil lewat `GET /api/v1/attachments/:signed_id`, yang membalas `302`
  ke MinIO. Gambar Dictionary berupa URL MinIO publik langsung. Agar jalan, MinIO harus bisa dijangkau browser
  (subdomain publik + HTTPS + CORS di MinIO).
- **Usulan:** Backend yang mengirim file. Semua file diambil lewat satu endpoint ber-JWT yang membalas `200` berisi
  file. MinIO tidak diekspos sama sekali.
- **Dampak FE:** kapal dan dokumen biasanya **tidak berubah**. Gambar **Dictionary berubah** (daftar, detail, form,
  dan offline bundle). Sisanya (login, upload, permission, endpoint lain) tidak berubah.

## 2. Kenapa Backend mengusulkan ini

- FE di HTTPS tidak bisa memuat `http://<ip>:9010/...` (mixed content). Memperbaikinya berarti subdomain + sertifikat
  + CORS MinIO untuk setiap environment, termasuk server Gov Brunei.
- Tanpa MinIO publik tidak ada URL sementara (5 menit) di riwayat browser/log, setiap pengambilan file melewati
  otorisasi dan tercatat, dan hanya ada satu bucket tanpa akses anonim. Lebih mudah lolos review keamanan Gov.
- File kecil (gambar kapal ≤2 MB, Dictionary ≤5 MB, PDF ≤10 MB), jadi dikirim lewat API masih wajar.

## 3. Perubahan kontrak API

### 3.1 `GET /api/v1/attachments/:signed_id`

| | Sekarang | Usulan |
|---|---|---|
| Respons sukses | `302 Found`, `Location` = URL MinIO bertanda tangan | `200 OK` berisi file |
| Header | `Cache-Control: private, max-age=0` | `Content-Type`, `Content-Disposition` (`inline`, atau `attachment` bila `?disposition=attachment`; tipe berisiko dipaksa `attachment`), `ETag`, `Cache-Control: max-age=0, private, must-revalidate` |
| Request ulang | selalu unduh ulang | kirim `If-None-Match: <ETag>` → `304` tanpa isi (otorisasi tetap dicek) |
| Kedaluwarsa | URL MinIO mati setelah 5 menit | tidak ada; selama JWT valid, path bisa diambil kapan saja |
| Error | `401/403/404` JSON dari API; setelah redirect, error XML dari MinIO | `401/403/404` JSON `{ "status": "fail", "message": ... }` dari API saja |
| Lintas origin | fetch ke domain MinIO (butuh CORS MinIO) | hanya domain API (CORS API yang sudah ada) |
| Parameter | `?disposition=inline\|attachment` | sama |

`<img src>` biasa tetap tidak bisa dipakai karena tidak mengirim header `Authorization` (JWT hanya dibaca dari
header; token di query string tidak didukung). Ini sudah berlaku untuk gambar kapal dan dokumen.

### 3.2 Field yang berubah

| Field | Dikirim oleh | Sekarang | Usulan |
|---|---|---|---|
| `image_urls[]` (gambar kapal) | `.../company_profiles/:id/vessels[/:id]` (namespace `admin` dan `fisherman`), `GET /fisherman/vessels` | `/api/v1/attachments/:sid` | **sama** |
| `document_url` (dokumen PDF) | `.../company_profiles/:id/documents`, `/admin/approvals/documents[/:id]` | `/api/v1/attachments/:sid` | **sama** |
| `image_url` (Dictionary) | `/admin/dictionaries[/:id]` (termasuk create/update), `/fisherman/dictionaries`, `/fisherman/manifests/:id/offline_bundle` → `data.dictionaries[]` | URL absolut MinIO publik, atau `null` | `/api/v1/attachments/<sid>` (path relatif), atau `null` |

```jsonc
// Dictionary, sekarang
"image_url": "https://minio-dofi.example/dofi-staging-public/abc123"
// Dictionary, usulan (path relatif terhadap domain API, perlu header Authorization)
"image_url": "/api/v1/attachments/eyJfcmFpbHMiOnsi..."
```

Tidak berubah: nama field, `null` bila tidak ada gambar, upload (multipart `dictionary[image]`,
`.../vessels/:id/images`, dokumen), validasi tipe/ukuran, dan model permission. Satu catatan: officer yang punya
`dictionaries.list` tetapi tidak punya `dictionaries.view` akan mendapat `403` untuk gambar Dictionary (nelayan selalu
boleh).

## 4. Yang perlu FE kerjakan

1. Satu pemuat file ber-auth untuk semua tipe (kapal, dokumen, Dictionary): awali path dengan base URL API, kirim
   `Authorization: Bearer <jwt>`, ubah respons jadi blob URL.
2. Dictionary: ganti `<img src={image_url}>` dengan pemuat itu (daftar, detail, preview di form edit).
3. Cache per path (Map) supaya gambar yang sama tidak diambil berulang, dan `URL.revokeObjectURL` saat komponen
   dibongkar. Daftar panjang: muat saat terlihat (lazy), bukan semuanya sekaligus.
4. Error: `401` → alur login yang sudah ada (JWT berlaku 1 hari); `403` dan `404` → placeholder, bukan gambar rusak.
5. Unduh file: `?disposition=attachment` lalu blob + `<a download>`. Nama file dari `Content-Disposition` (Backend
   akan meng-expose header itu di CORS) atau dari data record.
6. Offline bundle: lihat §5.
7. Kompatibel mundur selama transisi: lihat §6.

Contoh (ilustratif, sesuaikan dengan stack: axios, React Query, Vue, dst.):

```js
const cache = new Map(); // key -> Promise<blobUrl>

export function attachmentUrl(path, { token, disposition } = {}) {
  if (/^https?:\/\//.test(path)) return Promise.resolve(path); // URL absolut lama: pakai apa adanya
  const key = `${path}|${disposition ?? ""}`;
  if (!cache.has(key)) {
    const qs = disposition ? `?disposition=${disposition}` : "";
    const pending = fetch(`${API_BASE}${path}${qs}`, { headers: { Authorization: `Bearer ${token}` } })
      .then(async (res) => {
        if (!res.ok) throw Object.assign(new Error("attachment"), { status: res.status });
        return URL.createObjectURL(await res.blob());
      });
    pending.catch(() => cache.delete(key)); // jangan menyimpan error
    cache.set(key, pending);
  }
  return cache.get(key);
}
```

## 5. Offline bundle (bagian paling berisiko)

- `GET /api/v1/fisherman/manifests/:id/offline_bundle` memuat **semua** Dictionary, termasuk `image_url`, agar nelayan
  bisa memakainya saat tidak ada sinyal.
- Sekarang URL-nya publik, jadi apa pun cara FE menyimpannya tidak butuh token. Setelah perubahan, tiap gambar harus
  di-fetch dengan JWT lalu disimpan sebagai blob (IndexedDB/Cache Storage) dengan path sebagai kunci. Saat offline,
  baca dari penyimpanan lokal, jangan memanggil API.
- `signed_id` stabil dan tidak kedaluwarsa. Kalau gambar diganti, blob baru → path baru, jadi kunci cache otomatis
  berbeda.
- Beban: satu sinkronisasi bisa memicu ratusan request ber-auth. Sisi Backend (usulan): `ETag`/`304`, limit rate
  terpisah untuk `/api/v1/attachments/`. Sisi FE: konkurensi terbatas (±4), retry dengan backoff, prioritaskan gambar
  yang terlihat, kirim `If-None-Match` saat sinkron ulang.
- Keputusan produk yang perlu disepakati: apakah gambar Dictionary **wajib** tersedia offline (eager di bundle), atau
  cukup di-cache saat pernah dilihat (lazy)?

## 6. Urutan rilis dan kompatibilitas

1. **FE rilis dulu** dengan pemuat baru yang menerima kedua bentuk: path relatif → fetch ber-auth; URL absolut →
   dipakai apa adanya. Jalan dengan Backend lama maupun baru.
2. **Backend rilis** (staging dulu, uji bersama; production Gov adalah deploy baru, langsung versi baru).
3. FE boleh membuang cabang URL absolut setelah semua environment memakai versi baru.

Kalau Backend dirilis lebih dulu, gambar Dictionary rusak sampai FE rilis. Rollback Backend aman (revert + redeploy,
data tidak disentuh).

## 7. Uji bersama di staging

- [ ] Daftar dan detail Dictionary (admin), preview di form edit, upload gambar baru
- [ ] Daftar Dictionary sisi nelayan
- [ ] Gambar kapal (admin dan nelayan), upload gambar kapal
- [ ] Dokumen PDF: lihat dan unduh, termasuk layar approval
- [ ] Offline bundle: sinkron, matikan jaringan, gambar tetap tampil
- [ ] JWT kedaluwarsa saat memuat gambar → perilaku login sesuai harapan
- [ ] User tanpa izin → placeholder, bukan gambar rusak
- [ ] Console tanpa mixed content/CORS; Network: `200` (reload: `304`), tidak ada request ke domain MinIO

## 8. Pertanyaan untuk FE

1. Sekarang `image_url` Dictionary dipakai bagaimana (`<img src>`, CSS background, service worker precache, dibagikan)?
2. Sudah ada pemuat/komponen ber-auth untuk gambar kapal dan dokumen? Apakah ada kode yang menangani `302`
   secara manual (`redirect: "manual"`, membaca `Location`)?
3. Dari mana nama file unduhan diambil (header `Content-Disposition` atau data record)?
4. Offline: apakah PWA/service worker? Di mana gambar disimpan, dan berapa gambar yang ditarik sekaligus?
   Berapa jumlah Dictionary dan total ukurannya?
5. Apakah ada kebutuhan URL gambar publik di luar aplikasi (email, export PDF, dibagikan)? Backend tidak
   menyediakan URL publik.
6. Apakah daftar Dictionary memakai virtualisasi/lazy load sehingga tidak memuat semua thumbnail sekaligus?
7. Bagaimana FE menangani JWT kedaluwarsa (1 hari) di tengah pemuatan banyak gambar?
8. Bisakah FE rilis lebih dulu dengan pemuat yang kompatibel dua arah (§6)? Kapan jadwalnya?

## 9. Keputusan yang perlu disepakati

- Offline: eager (di bundle) atau lazy (§5).
- Jadwal rilis FE dulu, lalu Backend (§6).
- Apakah batas rate Backend untuk attachments (usulan ±1500 request / 5 menit / IP) cukup untuk pola pemakaian FE?
