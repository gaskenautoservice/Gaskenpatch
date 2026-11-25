GASKEN AUTO SERVICE V4 - PAKET UJI COBA ANDROID / WEB

ISI PAKET
- Aplikasi web responsif untuk HP Android dan komputer.
- Penyimpanan lokal IndexedDB dan cache Service Worker (localhost/HTTPS).
- Login prototipe dengan 4 peran: Pemilik/Admin, Kasir, Mekanik, Service Advisor.
- Work Order untuk Workshop dan Home Service.
- Biaya Home Service otomatis: maksimum(jarak KM x tarif per KM, biaya minimum).
- Pengaturan tarif per KM dan biaya minimum hanya dapat diakses Pemilik/Admin.
- Pengelolaan akun demo/karyawan lokal dan hak menu sesuai peran.
- supabase-schema.sql adalah rancangan awal, belum dihubungkan ke server.

AKUN DEMO
Pemilik/Admin   : admin / Gasken123!
Kasir           : kasir / Kasir123!
Mekanik         : mekanik / Mekanik123!
Service Advisor : advisor / Advisor123!

CARA UJI DI ANDROID (DISARANKAN)
1. Ekstrak ZIP ke sebuah folder.
2. Upload isi folder gasken-auto-service ke hosting HTTPS (misalnya GitHub Pages atau Cloudflare Pages).
3. Buka alamat HTTPS hasil publikasi melalui Chrome Android.
4. Menu Chrome (titik tiga) > Tambahkan ke layar utama / Install aplikasi.
5. Jalankan Gasken dari ikon layar utama dan login menggunakan akun demo di atas.

CARA UJI DI KOMPUTER
1. Ekstrak ZIP.
2. Buka terminal/Command Prompt di folder gasken-auto-service.
3. Jalankan: python -m http.server 8000
4. Buka http://localhost:8000 di browser.

CONTOH UJI TARIF HOME SERVICE
- Atur tarif per KM = Rp5.000 dan minimum = Rp50.000.
- Buat Work Order > Home Service > jarak 8 KM: biaya kunjungan Rp50.000.
- Ubah jarak menjadi 12 KM: biaya kunjungan Rp60.000.
- Jarak 0 KM: biaya kunjungan Rp0.

BATASAN PENTING - BUKAN UNTUK OPERASIONAL NYATA
- Ini prototipe V4 untuk pengujian fitur, bukan aplikasi produksi/APK native.
- Akun dan hak akses berjalan di browser/perangkat; tidak boleh dianggap aman untuk data nyata.
- Data tersimpan lokal di browser/perangkat tersebut; belum tersinkron antar HP/komputer.
- Menghapus data browser dapat menghapus data uji.
- Tarif awal Rp0; pemilik perlu mengatur tarif dan minimum sebelum menguji Home Service.
- SQL belum dijalankan di Supabase; autentikasi server, RLS teruji, sinkronisasi, backup, audit log, dan uji keamanan belum selesai.
- Jangan masukkan data pelanggan sungguhan atau informasi sensitif ke prototipe ini.
