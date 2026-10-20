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
  static const _apiKeyWeb = String.fromEnvironment('FIREBASE_API_KEY_WEB');
  static const _appIdAndroid = String.fromEnvironment('FIREBASE_APP_ID_ANDROID');
  static const _appIdIos = String.fromEnvironment('FIREBASE_APP_ID_IOS');
  static const _appIdWeb = String.fromEnvironment('FIREBASE_APP_ID_WEB');
  static const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  /// Kunci Web Push (VAPID) untuk meminta token di browser.
  static const vapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');

  static bool get _ios => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static String get _apiKey => kIsWeb ? _apiKeyWeb : (_ios ? _apiKeyIos : _apiKeyAndroid);
  static String get _appId => kIsWeb ? _appIdWeb : (_ios ? _appIdIos : _appIdAndroid);

  /// Push untuk aplikasi Android / iOS / web yang sudah dikonfigurasi.
  static bool get tersedia {
    if (kIsWeb) {
      if (vapidKey.isEmpty) return false;
    } else if (defaultTargetPlatform != TargetPlatform.android && !_ios) {
      return false;
    }
    return _apiKey.isNotEmpty && _appId.isNotEmpty && _senderId.isNotEmpty && _projectId.isNotEmpty;
  }

  static FirebaseOptions get options => FirebaseOptions(
        apiKey: _apiKey,
        appId: _appId,
        messagingSenderId: _senderId,
        projectId: _projectId,
        authDomain: kIsWeb ? '$_projectId.firebaseapp.com' : null,
        iosBundleId: _ios ? 'id.assalafiyah.portalsalaf' : null,
      );
}
