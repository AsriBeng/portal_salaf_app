/// Konfigurasi aplikasi.
///
/// Alamat API bisa diganti saat build tanpa mengubah kode, misalnya untuk server lokal:
/// `flutter run --dart-define=API_URL=http://192.168.1.10:8000/api`
class AppConfig {
  AppConfig._();

  static const appName = 'Portal Salaf';
  static const tagline = "Portal Santri As-Salafiyyah Asy-Syafi'iyyah";

  static const apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://portalsalaf.rupamedia.my.id/api',
  );
}
