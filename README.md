# Rayva 🏃‍♂️🔥

Aplikasi pelacak aktivitas (lari / jalan / sepeda) seperti Strava, dibuat dengan Flutter.

## Fitur
- **Rekam aktivitas GPS**: waktu, jarak, pace / kecepatan, kecepatan saat ini, bisa dijeda dan dilanjutkan.
- **Peta live**: jalur tergambar real-time dengan garis gradasi dan titik lokasi yang berdenyut, kamera mengikuti posisimu.
- **Tetap merekam saat layar mati** (Android memakai foreground service dengan notifikasi).
- **Animasi replay rute**: jalur "digambar" ulang dari start sampai finish, ada tombol play/pause, slider, kecepatan 1x/2x/4x/8x, dan mode kamera ikut jalur.
- Detail aktivitas: split per km, grafik elevasi, kalori, kecepatan maksimum.
- Statistik: grafik minggu ini, total, per jenis, rekor pribadi.
- **Aktivitas demo** (ikon ✨) untuk mencoba animasi tanpa harus keluar rumah.
- Data disimpan lokal di HP (shared_preferences).

Peta: OpenStreetMap + CARTO Dark (lewat `flutter_map`), **tidak perlu API key**.

## Install di HP (tanpa kabel USB, tanpa install Flutter)
APK dibuat otomatis oleh **GitHub Actions** (gratis, akun GitHub biasa sudah cukup).

1. Buat repo baru di https://github.com/new lalu upload/push seluruh isi folder ini
   (termasuk folder `.github` dan `android/keystore`).
2. Buka tab **Actions** di repo, tunggu workflow **Build APK** selesai (sekitar 5–10 menit, tanda ✅).
3. Dari HP, buka halaman **Releases** di repo → unduh file `rayva-v…apk`
   (atau dari halaman workflow → bagian *Artifacts* → `rayva-apk`, perlu login dan isinya berupa .zip).
4. Buka file APK di HP → izinkan **"Instal dari sumber tidak dikenal"** → **Install**.

Setiap kali ada perubahan yang di-push, APK baru otomatis dibuat. Karena kunci tanda tangan
(`android/keystore/rayva.keystore`) selalu sama, APK baru bisa langsung di-install
**di atas versi lama tanpa kehilangan data**. Build juga bisa dijalankan manual lewat
**Actions → Build APK → Run workflow**.

> ⚠️ Jangan hapus atau ganti `android/keystore/rayva.keystore`. Kalau berubah, aplikasi lama di HP
> harus di-uninstall dulu (data aktivitas ikut terhapus) sebelum versi baru bisa di-install.

## Untuk developer (opsional, butuh Flutter SDK)
```powershell
cd rayva
# Membuat folder platform (android/ios). File yang sudah ada TIDAK ditimpa.
flutter create --org com.rayva --project-name rayva --platforms android,ios .
flutter pub get
flutter run   # untuk debug/hot reload: HP terhubung lewat USB atau Wi-Fi (wireless debugging)
```
Build APK lokal: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`

### Android
`android/app/src/main/AndroidManifest.xml` sudah berisi izin lokasi, internet, dan foreground service.

### iOS (butuh macOS)
Tambahkan ke `ios/Runner/Info.plist`:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Rayva memakai lokasi untuk merekam rute aktivitasmu.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Rayva memakai lokasi untuk tetap merekam saat layar terkunci.</string>
<key>UIBackgroundModes</key>
<array><string>location</string></array>
```

## Struktur
```
lib/
  main.dart                     # App + navigasi bawah
  theme.dart                    # Warna & tema Rayva
  models/activity.dart          # Activity, TrackPoint, SportType
  services/tracking_controller.dart  # GPS, izin, timer, jeda
  services/activity_repository.dart  # Penyimpanan + generator demo
  utils/geo.dart                # Jarak kumulatif & interpolasi posisi
  utils/format.dart             # Format waktu/pace/tanggal
  widgets/route_replay_map.dart # ⭐ Animasi replay rute
  widgets/map_widgets.dart      # Tile layer, marker, preview peta
  screens/                      # Beranda, Rekam, Detail, Statistik
```

> Catatan: tile CARTO/OSM gratis untuk pengembangan dan penggunaan ringan. Untuk produksi
> sebaiknya pakai penyedia tile berbayar/milik sendiri (mis. MapTiler, Stadia, Mapbox).

