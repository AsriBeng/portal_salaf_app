import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Konfigurasi Firebase untuk push notification.
///
/// Nilai diisi saat build dari file `firebase-config.json` (lihat `firebase-config.example.json`):
/// `flutter run --dart-define-from-file=firebase-config.json`
///
/// Jika belum diisi, push notification dilewati; notifikasi di dalam aplikasi tetap berjalan.
class FirebaseConfig {
  FirebaseConfig._();

  static const _apiKeyAndroid = String.fromEnvironment('FIREBASE_API_KEY_ANDROID');
  static const _apiKeyIos = String.fromEnvironment('FIREBASE_API_KEY_IOS');
  static const _appIdAndroid = String.fromEnvironment('FIREBASE_APP_ID_ANDROID');
  static const _appIdIos = String.fromEnvironment('FIREBASE_APP_ID_IOS');
  static const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  static bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;

  /// Push hanya untuk aplikasi Android / iOS yang sudah dikonfigurasi.
  static bool get tersedia {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.android && !_ios) return false;
    final apiKey = _ios ? _apiKeyIos : _apiKeyAndroid;
    final appId = _ios ? _appIdIos : _appIdAndroid;
    return apiKey.isNotEmpty && appId.isNotEmpty && _senderId.isNotEmpty && _projectId.isNotEmpty;
  }

  static FirebaseOptions get options => FirebaseOptions(
        apiKey: _ios ? _apiKeyIos : _apiKeyAndroid,
        appId: _ios ? _appIdIos : _appIdAndroid,
        messagingSenderId: _senderId,
        projectId: _projectId,
        iosBundleId: _ios ? 'id.assalafiyah.portalsalaf' : null,
      );
}
