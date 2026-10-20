# ResQ — Flutter Prototype

ResQ adalah prototype aplikasi tanggap bencana berbasis Flutter yang memiliki fitur autentikasi, pelaporan, peta lokasi, informasi gempa BMKG, profil pengguna, permainan edukasi bertahan hidup, dan simulasi sensor.

## Teknologi

- Flutter dan Dart
- Supabase untuk autentikasi dan layanan backend
- OpenStreetMap untuk peta
- BMKG untuk informasi gempa
- SHA-256 untuk sidik jari integritas laporan

## Persiapan

1. Instal Flutter stable dan pastikan Flutter dapat dijalankan.
2. Jalankan `flutter pub get` untuk memasang dependensi.
3. Buat proyek Supabase dan siapkan konfigurasi autentikasi serta database sesuai kebutuhan aplikasi.
4. Buat file `.env` di direktori utama proyek berdasarkan `.env.example`.
5. Isi variabel lingkungan pada `.env` dengan konfigurasi yang sesuai.

Contoh struktur `.env`:

```env
SUPABASE_URL=
SUPABASE_PUBLISHABLE_KEY=
GEMINI_API_KEY=
```

Jangan masukkan nilai API key asli ke README atau commit Git. File `.env` harus tetap dikecualikan melalui `.gitignore`. Gunakan hanya kunci Supabase yang memang aman untuk aplikasi klien; jangan pernah menaruh `service_role` key di aplikasi Flutter.

## Menjalankan Aplikasi

Setelah konfigurasi selesai, jalankan:

```bash
flutter pub get
flutter run
```

Pastikan konfigurasi Supabase dan layanan terkait sudah benar sebelum menguji fitur yang memerlukan backend.

## Catatan Platform

- **Internet:** Pastikan izin internet tersedia pada konfigurasi Android di `android/app/src/main/AndroidManifest.xml`.
- **Lokasi dan peta:** Tambahkan izin lokasi pada platform terkait dan minta izin pengguna sebelum mengakses GPS. Peta dapat menggunakan titik pusat default dan penanda shelter demo.
- **Sensor:** Pemantauan sensor berorientasi pada aplikasi yang sedang berjalan. Eksekusi sensor di latar belakang Android memerlukan foreground service serta pengaturan siklus hidup dan izin khusus platform.
- **Sensor cahaya:** Tidak semua perangkat memiliki sensor cahaya atau menyediakan akses ke sensor tersebut. Developer Override tersedia untuk demonstrasi.
- **Integritas laporan:** SHA-256 merupakan sidik jari integritas, bukan blockchain dan bukan bukti bahwa laporan benar. Data yang di-hash oleh klien dapat dimanipulasi; sistem produksi sebaiknya melakukan hashing di server serta menerapkan verifikasi dan moderasi.
- **Keselamatan:** Jangan mengandalkan prototype ini sebagai satu-satunya sistem peringatan darurat. Verifikasi informasi darurat melalui sumber resmi setempat.