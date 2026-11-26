# 7. Cek koneksi AD MPRT dari server production (langkah demi langkah)

> Status: **sudah dijalankan 2026-11-26** (hasil di [Catatan hasil](#catatan-hasil)).
>
> **Keputusan 2026-11-26:** client memilih **LDAP biasa di port 389 tanpa TLS** (`AD_TRANSPORT=plain`), sama seperti
> integrasi AD mereka untuk AIMS dan TIMS, supaya tidak perlu root CA. Konsekuensinya: password officer lewat di
> jaringan antara backend dan domain controller **tanpa enkripsi**. Detail dan cara pindah ke LDAPS nanti ada di
> [active-directory-login.md, "Plain LDAP"](../registration/active-directory-login.md#plain-ldap-ad_transportplain).

## Kenapa dokumen ini ada

- Login AD untuk staff DoFi sudah dibuat, tapi **belum pernah dites ke AD yang asli**.
- AD MPRT (`mprt.eg.gov.bn`, DC: PRTAUTHPRO1/2/3) hanya bisa dijangkau dari **server production**, yang terisolasi dan
  hanya bisa diakses lewat **VPN + Delinea**. Dari laptop tidak bisa.
- Kode AD baru ada di `develop` (image `ghcr.io/arya020595/st_dofi_backend:staging`) dan **belum ada di `main`**.
  Jadi container production yang sedang jalan belum punya kode AD.
- Karena itu tes dijalankan dengan **container sekali pakai** (`docker run --rm`) dari image `:staging`. Stack
  production (`api`, `jobs`) **tidak di-restart** dan `.env` **tidak diubah**.

Tim AD memberi port **389**. Aplikasi menolak 389 dengan sengaja, karena bind biasa di 389 mengirim password officer
**tanpa enkripsi**. Script ini mencari jalur yang aman:

| Hasil | Langkah berikutnya |
|---|---|
| LDAPS di **636** atau **3269** berhasil | Cukup isi config `.env` saat release AD ke `main`. Tidak perlu ubah kode |
| Hanya **389 + StartTLS** yang berhasil | Developer menambahkan `AD_TLS_MODE=start_tls` ke kode (net-ldap 0.21 sudah mendukung, hostname tetap diverifikasi) |
| Tidak ada yang berhasil | Minta ke tim AD / network / PKI (lihat tabel [Cara membaca hasil](#cara-membaca-hasil)). **Jangan pernah** pakai 389 tanpa TLS |

## Checklist singkat

- [ ] Langkah 0: ganti password sementara service account dan pastikan akun mana yang milik DoFi
- [ ] Langkah 1: VPN → Delinea → backend server → `cd /opt/dofi`
- [ ] Langkah 2: `docker pull` image `:staging`
- [ ] Langkah 3: buat `/opt/dofi/ad-check.rb`
- [ ] Langkah 4: jalankan script (bind **sekali saja**)
- [ ] Langkah 5: hapus script
- [ ] Langkah 6: simpan output (tanpa password) dan kirim ke developer

## Langkah 0: Persiapan (sebelum masuk server)

1. **Ganti dulu password sementara** service account dari EGNC, ikuti "Change Password Guideline and FAQ" di email
   EGNC. Selama akun masih ditandai *must change password*, setiap bind LDAP akan ditolak (kode AD `773`) dan
   kelihatannya sama seperti password salah.
2. EGNC memberi **dua** service account. Tanyakan ke tim AD mana yang milik DoFi. Untuk tes cukup pakai **satu**.
3. Simpan password di password manager. **Jangan** tulis di file, chat, dokumen, atau commit.

Catatan: desain aplikasi tidak membutuhkan service account, karena setiap officer bind ke AD dengan akunnya sendiri.
Service account hanya dipakai di sini sebagai **akun tes** untuk membuktikan host, port, TLS, dan format `MPRT\nama`.
Service account tidak disimpan di aplikasi dan **bukan** user DoFi.

## Langkah 1: Masuk ke backend server

1. Sambungkan VPN.
2. Buka terminal SSH Delinea ke **backend server** (yang menjalankan container `api`).
3. Jalankan:

   ```bash
   cd /opt/dofi
   docker compose ps          # api harus Up; ini hanya untuk memastikan servernya benar
   ```

## Langkah 2: Ambil image `:staging`

```bash
docker pull ghcr.io/arya020595/st_dofi_backend:staging
```

Langkah ini tidak mengganggu production. Server sudah login ke GHCR. Kalau muncul `unauthorized`, token
`read:packages` sudah kedaluwarsa (lihat [PRODUCTION-DEPLOY-CHECKLIST](../ci-cd/PRODUCTION-DEPLOY-CHECKLIST.md)).

## Langkah 3: Buat file script

```bash
nano /opt/dofi/ad-check.rb
```

Tempel seluruh isi di bawah, simpan (`Ctrl+O`, Enter, `Ctrl+X`), lalu jalankan:

```bash
chmod 644 /opt/dofi/ad-check.rb
```

Script ini **tidak pernah** mengirim password lewat koneksi tanpa TLS yang terverifikasi dan **tidak mencetak**
password.

```ruby
# DoFi - cek koneksi Active Directory. Tidak mencetak password. Hapus file ini setelah dipakai.
require "socket"
require "openssl"
require "timeout"
require "io/console"
require "net/ldap"

DOMAIN  = "mprt.eg.gov.bn"
HOSTS   = [DOMAIN, "prtauthpro1.#{DOMAIN}", "prtauthpro2.#{DOMAIN}", "prtauthpro3.#{DOMAIN}"].freeze
NETBIOS = "MPRT"
WAIT    = 5
# LDAP ExtendedRequest StartTLS (OID 1.3.6.1.4.1.1466.20037), messageID 1
STARTTLS_REQUEST = ["301d02010177188016"].pack("H*") + "1.3.6.1.4.1.1466.20037"
AD_HINTS = { "52e" => "password salah", "773" => "wajib ganti password dulu", "775" => "akun terkunci",
             "533" => "akun dinonaktifkan", "532" => "password kedaluwarsa", "701" => "akun kedaluwarsa",
             "525" => "user tidak ditemukan" }.freeze

def tls_params
  OpenSSL::SSL::SSLContext::DEFAULT_PARAMS.merge(verify_mode: OpenSSL::SSL::VERIFY_PEER,
                                                 min_version: OpenSSL::SSL::TLS1_2_VERSION)
end

def addresses(host)
  Addrinfo.getaddrinfo(host, nil, nil, :STREAM).map(&:ip_address).uniq.join(", ")
rescue SocketError => e
  "TIDAK TERRESOLVE (#{e.message})"
end

def port_state(host, port)
  Socket.tcp(host, port, connect_timeout: WAIT).close
  "terbuka"
rescue StandardError => e
  "tertutup/terblokir (#{e.class})"
end

def starttls!(tcp)
  tcp.write(STARTTLS_REQUEST)
  Timeout.timeout(WAIT) do
    tag, len = tcp.read(2).bytes
    raise "bukan balasan LDAP" unless tag == 0x30
    len = tcp.read(len & 0x7f).bytes.inject(0) { |a, b| (a << 8) | b } if (len & 0x80) != 0
    body = tcp.read(len)
    i = body.index("\x0A\x01".b) or raise "balasan StartTLS tanpa result code"
    code = body.getbyte(i + 2)
    raise "server menolak StartTLS (LDAP result #{code})" unless code.zero?
  end
end

def tls_check(host, port, starttls:)
  tcp = Socket.tcp(host, port, connect_timeout: WAIT)
  starttls!(tcp) if starttls
  ctx = OpenSSL::SSL::SSLContext.new
  ctx.set_params(tls_params)
  ssl = OpenSSL::SSL::SSLSocket.new(tcp, ctx)
  ssl.hostname = host
  ssl.sync_close = true
  Timeout.timeout(WAIT) { ssl.connect }
  ssl.post_connection_check(host)
  cert = ssl.peer_cert
  san = cert.extensions.find { |x| x.oid == "subjectAltName" }&.value
  info = "OK #{ssl.ssl_version}, berlaku s/d #{cert.not_after.utc}, issuer #{cert.issuer}, SAN: #{san}"
  ssl.close
  [true, info]
rescue StandardError => e
  tcp&.close rescue nil
  [false, "GAGAL #{e.class}: #{e.message[0, 200]}"]
end

def bind_once(host, port, method, user, password)
  ldap = Net::LDAP.new(host: host, port: port, connect_timeout: WAIT,
                       encryption: { method: method, tls_options: tls_params },
                       auth: { method: :simple, username: "#{NETBIOS}\\#{user}", password: password })
  return "BIND BERHASIL - AD menerima akun ini" if Timeout.timeout(15) { ldap.bind }

  r = ldap.get_operation_result
  data = r.error_message.to_s[/data ([0-9a-f]+)/, 1]
  "BIND DITOLAK: LDAP code #{r.code} #{r.message} | data #{data} (#{AD_HINTS.fetch(data, 'lihat pesan')})"
rescue StandardError => e
  "BIND ERROR #{e.class}: #{e.message[0, 200]}"
end

puts "== 1. DNS"
HOSTS.each { |h| puts "  #{h} -> #{addresses(h)}" }

puts "== 2. Port"
HOSTS.each { |h| [389, 636, 3269].each { |p| puts "  #{h}:#{p} #{port_state(h, p)}" } }

puts "== 3. TLS (sertifikat + hostname diverifikasi)"
working = []
HOSTS.each do |h|
  [[636, :simple_tls], [3269, :simple_tls], [389, :start_tls]].each do |port, method|
    ok, info = tls_check(h, port, starttls: method == :start_tls)
    label = method == :start_tls ? "StartTLS" : "LDAPS"
    puts "  #{h}:#{port} #{label}: #{info}"
    working << [h, port, method] if ok
  end
end

puts "== 4. Bind (sekali saja)"
if working.empty?
  puts "  Dilewati: tidak ada jalur TLS yang terverifikasi. Password TIDAK dikirim."
else
  h, port, method = working.first
  print "  Tes bind lewat #{h}:#{port} (#{method})? ketik y untuk lanjut: "
  if $stdin.gets.to_s.strip.downcase == "y"
    print "  Username AD (tanpa MPRT\\, huruf kecil): "
    user = $stdin.gets.to_s.strip.downcase
    print "  Password (tidak tampil): "
    password = $stdin.noecho(&:gets).to_s.chomp
    puts
    puts "  #{bind_once(h, port, method, user, password)}"
    password = nil
  else
    puts "  Dilewati."
  end
end
puts "== Selesai. Kirim output ini (tanpa password) ke developer."
```

## Langkah 4: Jalankan

```bash
docker run --rm -it -v /opt/dofi/ad-check.rb:/tmp/ad-check.rb:ro \
  ghcr.io/arya020595/st_dofi_backend:staging bundle exec ruby /tmp/ad-check.rb
```

- Bagian 1 sampai 3 butuh sekitar 1-2 menit (timeout 5 detik per percobaan).
- Di bagian 4: ketik `y`, lalu username (tanpa `MPRT\`, **huruf kecil**), lalu password.
- **Satu kali saja.** Kalau ditolak, **jangan diulang**, karena tiap password salah menambah hitungan lockout AD.
  Kirim hasilnya dulu ke developer.

## Langkah 5: Bersihkan

```bash
rm /opt/dofi/ad-check.rb
history -c   # opsional
```

Image `:staging` boleh dibiarkan. Kalau ingin menghemat disk:
`docker image rm ghcr.io/arya020595/st_dofi_backend:staging`.

## Langkah 6: Simpan dan kirim output

Salin seluruh output dari `== 1. DNS` sampai `== Selesai` lalu kirim ke developer. Output tidak berisi password.

## Cara membaca hasil

| Yang terlihat | Artinya | Lanjut ke |
|---|---|---|
| DNS `TIDAK TERRESOLVE` | Server tidak bisa resolve nama AD | Tim network: DNS resolver ke domain MPRT |
| Port `tertutup/terblokir (Errno::ETIMEDOUT)` | Diblok firewall | Minta rule firewall dari backend server ke **ketiga** DC, untuk port yang dipakai |
| Port `tertutup/terblokir (Errno::ECONNREFUSED)` | Host terjangkau, tapi port tidak listen | Tim AD: LDAPS aktif di port mana? |
| TLS `certificate verify failed (unable to get local issuer certificate)` | CA sertifikat AD tidak dikenal image | Minta root/intermediate CA (PEM) ke tim AD/PKI, set `AD_CA_FILE` |
| TLS `hostname ... does not match` | Sertifikat tidak memuat nama itu | Pakai nama yang ada di `SAN:` sebagai `AD_HOST` |
| TLS `server menolak StartTLS` | 389 tidak mendukung TLS | Tim AD |
| `BIND BERHASIL` | Host, port, TLS, dan format `MPRT\nama` sudah benar | Lanjut ke config + mapping user (di bawah) |
| `BIND DITOLAK ... data 773` | Password sementara belum diganti | Ganti password, baru tes ulang |
| `BIND DITOLAK ... data 52e` / `775` / `533` | Password salah / akun terkunci / akun nonaktif | Cek ke tim AD. **Jangan** diulang-ulang |

## Setelah tes berhasil

**Config production sesuai keputusan client** (di `/opt/dofi/.env`, setelah release `AD_TRANSPORT` masuk ke `main`
dan image baru di-pull; detail lengkap di
[active-directory-login.md](../registration/active-directory-login.md#production-values)):

```dotenv
AD_MODE=ldap
AD_TRANSPORT=plain
AD_HOST=prtauthpro1.mprt.eg.gov.bn,prtauthpro2.mprt.eg.gov.bn,prtauthpro3.mprt.eg.gov.bn
AD_PORT=389
AD_NETBIOS_DOMAIN=MPRT
AD_DNS_DOMAIN=MPRT.EG.GOV.BN
AD_BIND_FORMAT=netbios
AD_CA_FILE=
```

Untuk pindah ke LDAPS nanti (tanpa ubah kode): `AD_TRANSPORT=ldaps`, `AD_PORT=636`, `AD_CA_FILE=/etc/dofi/ad-ca.pem`
(root CA MPRT di-mount ke container). Port 636 sudah terbuka ke ketiga DC.

**Yang perlu diminta ke client:**

- [ ] Username AD **Super Admin**, untuk
      `bin/rails admin:assign_ad_username EMAIL=admin@dofi.gov.bn AD_USERNAME=mprt/<nama>`
- [ ] Daftar **username AD officer → role DoFi**. Super Admin lalu membuat user lewat Add User dengan username
      `mprt/<sAMAccountName>`
- [ ] Konfirmasi akun service account mana yang milik DoFi
- [ ] Rule firewall dari backend server ke **ketiga** DC untuk port yang dipakai. Rule yang ada sekarang hanya
      3268/3269 ke PRTAUTHPRO2/3
- [ ] Setelah tes selesai, minta EGNC merotasi password service account yang sempat dibagikan lewat chat/screenshot

**Yang sudah diputuskan:**

- Admin dan officer ditentukan oleh **role di database DoFi**, bukan oleh grup AD. AD hanya mengecek password.
- **Jetty Manager tetap tidak lewat AD.** Hanya role platform DoFi Officer yang login lewat AD.
- Transport: **LDAP biasa di 389** (`AD_TRANSPORT=plain`), keputusan client 2026-11-26. Default kode tetap LDAPS, dan
  LDAPS tidak pernah jatuh ke plaintext diam-diam.

## Catatan hasil

| Tanggal | Dijalankan oleh | DNS | Port terbuka | TLS yang OK | Bind | Catatan |
|---|---|---|---|---|---|---|
| 2026-11-26 | localadmin (backend server, dari container `api`) | OK: `mprt.eg.gov.bn` → 3 DC; PRTAUTHPRO1/2/3 masing-masing resolve | 389 dan 636 terbuka ke ketiga DC; 3269 `ETIMEDOUT` (diblok) | Belum ada. 636 LDAPS dan 389 StartTLS sama-sama `unable to get local issuer certificate` | Dilewati (tidak ada TLS yang terverifikasi) | Port **636** bisa dipakai, tidak perlu kode StartTLS. Butuh root/intermediate CA dari tim AD untuk `AD_CA_FILE`. Kecocokan hostname (SAN) belum dicek |
