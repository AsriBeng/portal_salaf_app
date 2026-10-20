import 'package:flutter/foundation.dart';

/// Konfigurasi aplikasi.
///
/// Alamat API bisa diganti saat build tanpa mengubah kode, misalnya untuk server lokal:
/// `flutter run --dart-define=API_URL=http://192.168.1.10:8000/api`
class AppConfig {
  AppConfig._();

  static const appName = 'Portal Salaf';
  static const tagline = "Portal Santri As-Salafiyyah Asy-Syafi'iyyah";

  static const _apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://portalsalaf.rupamedia.my.id/api',
  );

  /// Versi web disajikan dari domain yang sama dengan API (folder /app di Laravel),
  /// jadi cukup memakai alamat situs yang sedang dibuka.
  static String get apiUrl =>
      kIsWeb && !bool.hasEnvironment('API_URL') ? '${Uri.base.origin}/api' : _apiUrl;
}
