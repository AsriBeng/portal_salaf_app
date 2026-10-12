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

/// Mengelola push notification Firebase: izin, token perangkat, dan membuka halaman saat notifikasi diketuk.
class PushService {
  PushService(this._ref);

  final Ref _ref;
  bool _siap = false;
  String? _token;
  final _langganan = <StreamSubscription<dynamic>>[];

  /// Token perangkat saat ini (dikirim saat logout supaya server berhenti mengirim push).
  String? get token => _token;

  /// Dipanggil setelah login / saat sesi dipulihkan.
  Future<void> mulai() async {
    if (!FirebaseConfig.tersedia) return;

    try {
      if (!_siap) {
        await Firebase.initializeApp(options: FirebaseConfig.options);
        _pasangListener();
        _siap = true;
      }

      final messaging = FirebaseMessaging.instance;
      final izin = await messaging.requestPermission();
      if (izin.authorizationStatus == AuthorizationStatus.denied) return;

      _token = await messaging.getToken();
      if (_token != null) await _daftarkan(_token!);

      // Aplikasi dibuka dari notifikasi saat tertutup penuh
      final awal = await messaging.getInitialMessage();
      if (awal != null) _buka(awal.data);
    } catch (e) {
      debugPrint('Push notification tidak aktif: $e');
    }
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

  Future<void> _daftarkan(String token) async {
    try {
      await _ref.read(apiClientProvider).post('/device-tokens', data: {
        'token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      });
    } on ApiException catch (e) {
      debugPrint('Gagal mendaftarkan perangkat: ${e.message}');
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
