<div align="center">

<img src="assets/images/logo.png" alt="Logo Pondok Pesantren As-Salafiyyah Asy-Syafi'iyyah" width="120">

# Portal Salaf

**Portal Santri As-Salafiyyah Asy-Syafi'iyyah**<br>
Aplikasi mobile (Android & iOS) untuk santri, wali, dan pengurus pondok.

<img src="https://img.shields.io/badge/Flutter-3.47-02569B?style=flat-square&logo=flutter&logoColor=white" alt="Flutter">
<img src="https://img.shields.io/badge/State-Riverpod%203-0b6b3a?style=flat-square" alt="Riverpod">
<img src="https://img.shields.io/badge/Push-Firebase-FFCA28?style=flat-square&logo=firebase&logoColor=black" alt="Firebase">

</div>

## ▶️ Menjalankan

```bash
flutter pub get
flutter run -d chrome                 # di browser
flutter run                           # di HP Android yang tersambung USB
```

Secara bawaan aplikasi memakai API `https://portalsalaf.rupamedia.my.id/api`. Untuk server lokal (Laragon), jalankan dulu `php artisan serve` di folder API, lalu:

```bash
flutter run -d chrome --dart-define=API_URL=http://127.0.0.1:8000/api
```

> Dari HP Android, `127.0.0.1` adalah HP itu sendiri. Gunakan IP laptop di jaringan Wi-Fi yang sama, misalnya `http://192.168.1.10:8000/api`, dan jalankan `php artisan serve --host=0.0.0.0`.

Tombol di terminal saat aplikasi berjalan: `r` hot reload, `R` restart, `q` berhenti.

## 🔔 Push Notification (Firebase)

Tanpa konfigurasi ini aplikasi tetap berjalan normal. Notifikasi tetap tersedia di menu lonceng, hanya tidak muncul di bilah notifikasi HP.

1. Buka [Firebase Console](https://console.firebase.google.com), buat proyek baru.
2. **Tambah aplikasi Android** dengan package name `id.assalafiyah.portalsalaf`, lalu unduh `google-services.json`.
3. (Untuk iOS) **Tambah aplikasi iOS** dengan bundle ID `id.assalafiyah.portalsalaf`, unduh `GoogleService-Info.plist`, lalu unggah **APNs Authentication Key** di *Project settings → Cloud Messaging*. Aktifkan juga capability *Push Notifications* dan *Background Modes → Remote notifications* di Xcode.
4. Salin `firebase-config.example.json` menjadi `firebase-config.json`, lalu isi nilainya dari kedua file di atas (petunjuk ada di setiap kolom).
5. Jalankan / build dengan konfigurasi tersebut:
   ```bash
   flutter run --dart-define-from-file=firebase-config.json
   flutter build apk --release --dart-define-from-file=firebase-config.json
   ```
6. Di sisi **server API**, unduh *service account key* (Project settings → Service accounts → Generate new private key), simpan di hosting, dan isi `FCM_CREDENTIALS` di `.env` API.

`firebase-config.json`, `google-services.json`, dan `GoogleService-Info.plist` sudah masuk `.gitignore`. Jangan diunggah ke repositori publik.

## 📦 Rilis Android

1. **Buat kunci rilis (sekali saja).** Simpan file `.jks` dan password-nya baik-baik. Jika hilang, aplikasi di Play Store tidak bisa diperbarui.
   ```bash
   keytool -genkey -v -keystore C:\Users\NAMA\portal-salaf-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias portalsalaf
   ```
2. Salin `android/key.properties.example` menjadi `android/key.properties`, lalu isi password dan lokasi file `.jks`.
3. Naikkan versi di `pubspec.yaml` setiap rilis, misalnya `version: 1.0.1+2` (angka setelah `+` wajib naik).
4. Build:
   ```bash
   flutter build appbundle --release --dart-define-from-file=firebase-config.json   # untuk Play Store (.aab)
   flutter build apk --release --dart-define-from-file=firebase-config.json         # untuk dibagikan langsung (.apk)
   ```
   Hasilnya ada di `build/app/outputs/`.

`key.properties` dan file `.jks` sudah masuk `.gitignore`.

## 🗂️ Struktur

```
lib/
├── core/        konfigurasi, tema, klien API, router, push notification
├── models/      model data dan hak akses per peran (akses.dart)
├── shared/      widget dan helper yang dipakai bersama
└── features/    auth, home, santri, komplek, kartu, keuangan, pengumuman, notifikasi, profile
```

## 🧪 Test

```bash
flutter analyze
flutter test
```

---

<div align="center">
Dibuat oleh <a href="https://github.com/AsriBeng">@AsriBeng</a> untuk Pondok Pesantren As-Salafiyyah Asy-Syafi'iyyah
</div>
