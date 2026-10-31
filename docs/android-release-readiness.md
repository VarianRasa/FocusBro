# Android Release Readiness

Tanggal audit: 2026-06-15

## Status Ringkas

FocusBro belum siap untuk production release, tetapi sudah bisa diarahkan ke jalur release yang aman. Perubahan lokal pada tahap ini hanya menutup risiko release build memakai debug signing dan menambahkan pemeriksaan konfigurasi Android/Firebase.

Tidak ada perubahan Firebase remote, Play Store upload, production deploy, atau keystore asli.

## Android Identity

| Item | Nilai saat ini | Catatan |
| --- | --- | --- |
| App label | `FocusBro` | Dari `android/app/src/main/AndroidManifest.xml`. |
| Namespace | `com.example.focusbro` | Dari `android/app/build.gradle`. |
| Application ID | `com.example.focusbro` | Cocok dengan Firebase Android app saat ini. |
| Firebase project | `focusbro-35cd2` | Dari `android/app/google-services.json` dan `lib/firebase_options.dart`. |
| Firebase Android app id | `1:187168838711:android:276d188c4e9270df689bb2` | Cocok antara `google-services.json` dan `firebase_options.dart`. |
| Version | `1.0.0+1` | `pubspec.yaml`; Android memakai `local.properties` untuk `versionName=1.0.0`, `versionCode=1`. |

Keputusan tahap ini: applicationId tidak diubah. Mengubah `com.example.focusbro` akan memutus kecocokan dengan `android/app/google-services.json`, Firebase Android app, OAuth/SHA certificate setup, Crashlytics, dan Analytics stream yang sudah dibuat untuk package itu.

Rekomendasi package produksi: gunakan reverse-DNS milik owner, misalnya `com.focusbro.app` hanya bila domain/brand tersebut benar-benar dimiliki. Jika tidak, gunakan package sesuai entitas legal/domain owner, misalnya `com.<company>.focusbro`. Migrasi package harus dilakukan sebagai pekerjaan terpisah: buat Android app baru di Firebase, unduh `google-services.json` baru, regenerate `lib/firebase_options.dart`, set SHA upload key, dan uji Auth/Analytics/Crashlytics dari awal.

## Signing

Sebelum tahap ini, release build memakai:

```gradle
signingConfig signingConfigs.debug
```

Itu tidak aman untuk distribusi. Konfigurasi sekarang membaca `android/key.properties` bila file itu ada, memvalidasi empat key wajib, dan hanya memasang `signingConfigs.release` jika konfigurasi signing lengkap. Jika file signing belum ada, release build tidak memakai debug key.

File rahasia yang tidak boleh masuk repo:

- `android/key.properties`
- `android/app/*.jks`
- `android/app/*.keystore`

Template aman tersedia di `android/key.properties.example`.

Format yang disarankan untuk `android/key.properties`:

```properties
storeFile=app/upload-keystore.jks
storePassword=<secret>
keyAlias=upload
keyPassword=<secret>
```

Owner masih perlu membuat upload keystore asli di luar tahap ini dan menyimpannya aman. Untuk Google Play, gunakan Play App Signing dan upload key sesuai panduan resmi Flutter/Android.

## Permissions

| Permission | Kategori | Alasan fitur | Risiko release |
| --- | --- | --- | --- |
| `INTERNET` | Core | Firebase, sync, web/cloud features. | Rendah, tetapi privacy disclosure harus konsisten. |
| `RECEIVE_BOOT_COMPLETED` | Core Android | Menjaga reminder/schedule setelah restart. | Rendah-menengah; pastikan tidak memulai work berat saat boot. |
| `VIBRATE` | Core UX | Reminder/focus notifications. | Rendah. |
| `POST_NOTIFICATIONS` | Runtime | Reminder, focus session, achievement notification. | Normal di Android 13+. Perlu rationale dan denied-state yang baik. |
| `SCHEDULE_EXACT_ALARM` | Special/high risk | Reminder presisi dan follow-up focus/task. | Android 14+ tidak otomatis grant untuk banyak app. Harus ada fallback saat denied. |
| `USE_FULL_SCREEN_INTENT` | High Play risk | Potensi notifikasi sangat penting. | Google Play membatasi untuk calling/alarm use case. Perlu review kuat atau hapus jika tidak benar-benar alarm. |
| `ACCESS_NOTIFICATION_POLICY` | Special access | Do Not Disturb saat focus mode. | User harus grant manual. Harus optional dan jelas. |
| `RECORD_AUDIO` | Sensitive runtime | Voice notes dan voice commands. | Perlu disclosure, privacy controls, dan data handling jelas. |
| `WRITE_SETTINGS` | Special access | Focus/brightness/system behavior. | Review apakah benar digunakan; jangan minta jika fitur bisa tanpa permission ini. |
| `SYSTEM_ALERT_WINDOW` | Special/high risk | Overlay/blocking flow. | Play/user-trust risk tinggi. Harus optional, jelas, dan hanya saat dibutuhkan. |
| `QUERY_ALL_PACKAGES` | Restricted/high Play risk | Native app-blocking list membaca installed non-system apps. | Perlu Play declaration dan bukti bahwa broad app visibility adalah core functionality. Pertimbangkan alternatif minimum-scope. |
| `PACKAGE_USAGE_STATS` | Special/protected | Future usage-based blocking/status. | Saat ini foreground blocking memakai Accessibility service; review apakah permission ini masih perlu. |
| `USE_BIOMETRIC` | Core security | App lock biometrics. | Rendah, selama fallback PIN tersedia. |
| Accessibility service | Restricted API | App blocking berdasarkan foreground app. | Harus didokumentasikan di listing, memakai prominent disclosure/consent, dan tidak boleh untuk automation yang melampaui tujuan sempit. |

Catatan tambahan: `PermissionsService` juga memeriksa `manageExternalStorage` dan `requestInstallPackages`, tetapi manifest saat ini tidak mendeklarasikan keduanya. Sebelum Play release, rapikan daftar permission UI agar hanya menampilkan permission yang benar-benar dideklarasikan dan dibutuhkan.

## Build Commands

Command aman untuk tahap ini:

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

Release build belum dijalankan sebagai bukti produksi karena upload keystore asli belum tersedia. Setelah owner menyiapkan `android/key.properties` dan keystore:

```powershell
flutter build appbundle --release --build-name 1.0.0 --build-number 1
flutter build apk --release --build-name 1.0.0 --build-number 1
```

Untuk Play Store, AAB adalah artefak utama.

## Owner Decisions Before Production

1. Tentukan package produksi final dan domain/entitas pemiliknya.
2. Jika package berubah dari `com.example.focusbro`, buat Firebase Android app baru dan regenerate konfigurasi FlutterFire.
3. Generate upload keystore asli, simpan di secret storage, dan isi `android/key.properties` lokal/CI.
4. Tentukan apakah `USE_FULL_SCREEN_INTENT`, `QUERY_ALL_PACKAGES`, `PACKAGE_USAGE_STATS`, `SYSTEM_ALERT_WINDOW`, dan Accessibility service benar-benar wajib untuk core app.
5. Siapkan Play Console declarations untuk restricted permissions/API yang dipertahankan.
6. Lengkapi privacy policy, prominent disclosure, consent flow, dan store listing untuk microphone, analytics/crash reporting, installed-app visibility, dan Accessibility.
7. Jalankan QA release signed di device bersih: install, cold start, task/focus/reminder, app blocking, DND, backup/restore, Firebase observability.

## Referensi Resmi

- Flutter Android deployment and signing: https://docs.flutter.dev/deployment/android
- Android app signing: https://developer.android.com/studio/publish/app-signing
- Android special permissions: https://developer.android.com/training/permissions/requesting-special
- Android exact alarm changes: https://developer.android.com/about/versions/14/changes/schedule-exact-alarms
- Android full-screen intent changes: https://developer.android.com/about/versions/14/behavior-changes-14
- Google Play `QUERY_ALL_PACKAGES` policy: https://support.google.com/googleplay/android-developer/answer/10158779
- Google Play Accessibility API policy: https://support.google.com/googleplay/android-developer/answer/10964491
