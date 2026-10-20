import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/dashboard_provider.dart';
import '../features/pengumuman/pengumuman_repository.dart';
import 'api_client.dart';
import 'firebase_config.dart';
import 'router.dart';
import 'theme.dart';

/// Untuk menampilkan pesan dari luar widget (misalnya notifikasi saat aplikasi terbuka).
final pesanGlobalKey = GlobalKey<ScaffoldMessengerState>();

/// Status notifikasi push di browser (versi web).
enum StatusPushWeb {
  /// Push belum dikonfigurasi saat build.
  belumDiatur,

  /// Browser tidak mendukung (misalnya iPhone yang belum dipasang ke Layar Utama).
  tidakDidukung,
  belumAktif,
  ditolak,
  aktif,
}

/// Mengelola push notification Firebase: izin, token perangkat, dan membuka halaman saat notifikasi diketuk.
class PushService {
  PushService(this._ref);

  final Ref _ref;
  bool _siap = false;
  String? _token;
  final _langganan = <StreamSubscription<dynamic>>[];

  /// Token perangkat saat ini (dikirim saat logout supaya server berhenti mengirim push).
  String? get token => _token;

  /// Siapkan Firebase sekali saja.
  Future<void> _siapkan() async {
    if (_siap) return;
    await Firebase.initializeApp(options: FirebaseConfig.options);
    _pasangListener();
    _siap = true;
  }

  Future<String?> _ambilToken() =>
      FirebaseMessaging.instance.getToken(vapidKey: kIsWeb ? FirebaseConfig.vapidKey : null);

  /// Dipanggil setelah login / saat sesi dipulihkan.
  Future<void> mulai() async {
    if (!FirebaseConfig.tersedia) return;

    try {
      if (kIsWeb) {
        // Browser hanya boleh meminta izin dari tombol yang diketuk pengguna
        // (lihat aktifkanWeb). Di sini cukup daftar ulang jika izin sudah pernah diberikan.
        if (await statusWeb() == StatusPushWeb.aktif) {
          _token = await _ambilToken();
          if (_token != null) await _daftarkan(_token!);
        }
        return;
      }

      await _siapkan();
      final messaging = FirebaseMessaging.instance;
      final izin = await messaging.requestPermission();
      if (izin.authorizationStatus == AuthorizationStatus.denied) return;

      _token = await _ambilToken();
      if (_token != null) await _daftarkan(_token!);

      // Aplikasi dibuka dari notifikasi saat tertutup penuh
      final awal = await messaging.getInitialMessage();
      if (awal != null) _buka(awal.data);
    } catch (e) {
      debugPrint('Push notification tidak aktif: $e');
    }
  }

  /// Status izin notifikasi di browser.
  Future<StatusPushWeb> statusWeb() async {
    if (!FirebaseConfig.tersedia) return StatusPushWeb.belumDiatur;
    try {
      await _siapkan();
      final messaging = FirebaseMessaging.instance;
      if (!await messaging.isSupported()) return StatusPushWeb.tidakDidukung;
      final izin = await messaging.getNotificationSettings();
      return switch (izin.authorizationStatus) {
        AuthorizationStatus.authorized || AuthorizationStatus.provisional => StatusPushWeb.aktif,
        AuthorizationStatus.denied || AuthorizationStatus.deniedPermanently => StatusPushWeb.ditolak,
        AuthorizationStatus.notDetermined => StatusPushWeb.belumAktif,
      };
    } catch (e) {
      debugPrint('Status push web tidak diketahui: $e');
      return StatusPushWeb.tidakDidukung;
    }
  }

  /// Minta izin notifikasi di browser lalu daftarkan token. Harus dipanggil dari ketukan tombol.
  Future<StatusPushWeb> aktifkanWeb() async {
    final status = await statusWeb();
    if (status == StatusPushWeb.belumDiatur || status == StatusPushWeb.tidakDidukung) return status;

    final izin = await FirebaseMessaging.instance.requestPermission();
    if (izin.authorizationStatus case AuthorizationStatus.denied || AuthorizationStatus.deniedPermanently) {
      return StatusPushWeb.ditolak;
    }
    if (izin.authorizationStatus == AuthorizationStatus.notDetermined) return StatusPushWeb.belumAktif;

    _token = await _ambilToken();
    if (_token == null) throw ApiException('Browser tidak memberikan token notifikasi.');
    await _daftarkan(_token!, lempar: true);
    return StatusPushWeb.aktif;
  }

  void _pasangListener() {
    final messaging = FirebaseMessaging.instance;

    _langganan.add(messaging.onTokenRefresh.listen((t) {
      _token = t;
      _daftarkan(t);
    }));

    // Notifikasi datang saat aplikasi sedang dibuka: tampilkan di dalam aplikasi
    _langganan.add(FirebaseMessaging.onMessage.listen((pesan) {
      _ref.invalidate(notifBelumDibacaProvider);
      _ref.invalidate(dashboardProvider);

      final n = pesan.notification;
      if (n == null) return;
      pesanGlobalKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          backgroundColor: AppColors.hijauTua,
          duration: const Duration(seconds: 6),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n.title ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
              if (n.body != null) Text(n.body!, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
          ),
          action: SnackBarAction(label: 'Buka', textColor: AppColors.emas, onPressed: () => _buka(pesan.data)),
        ));
    }));

    // Notifikasi diketuk saat aplikasi di latar belakang
    _langganan.add(FirebaseMessaging.onMessageOpenedApp.listen((pesan) => _buka(pesan.data)));
  }

  Future<void> _daftarkan(String token, {bool lempar = false}) async {
    try {
      await _ref.read(apiClientProvider).post('/device-tokens', data: {
        'token': token,
        'platform': kIsWeb
            ? 'web'
            : defaultTargetPlatform == TargetPlatform.iOS
                ? 'ios'
                : 'android',
      });
    } on ApiException catch (e) {
      debugPrint('Gagal mendaftarkan perangkat: ${e.message}');
      if (lempar) rethrow;
    }
  }

  /// Buka halaman sesuai data notifikasi: {tipe, ref_id}.
  void _buka(Map<String, dynamic> data) {
    final id = data['ref_id'];
    final path = switch (data['tipe']) {
      'pengumuman' => '/pengumuman/$id',
      'tagihan' => '/tagihan/$id',
      'pembayaran' => '/pembayaran/$id',
      _ => '/notifikasi',
    };
    _ref.invalidate(notifBelumDibacaProvider);
    _ref.read(routerProvider).push(id == null || '$id'.isEmpty ? '/notifikasi' : path);
  }

  void dispose() {
    for (final l in _langganan) {
      l.cancel();
    }
  }
}

final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(ref);
  ref.onDispose(service.dispose);
  return service;
});
