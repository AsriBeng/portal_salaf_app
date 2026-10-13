import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/push_service.dart';
import '../../core/token_storage.dart';
import '../../models/user.dart';

/// Status login. `null` = belum login. Saat masih memeriksa token, state berupa loading (layar splash).
class AuthController extends AsyncNotifier<User?> {
  ApiClient get _api => ref.read(apiClientProvider);
  TokenStorage get _tokens => ref.read(tokenStorageProvider);

  @override
  Future<User?> build() async {
    // Token ditolak server di tengah pemakaian → kembali ke halaman login
    ref.read(unauthorizedHandlerProvider).callback = _sesiBerakhir;

    // Tampilkan splash minimal sebentar supaya tidak berkedip
    final jeda = Future<void>.delayed(const Duration(milliseconds: 1200));

    final token = await _tokens.read();
    if (token == null) {
      await jeda;
      return null;
    }

    try {
      final res = await _api.get('/me');
      await jeda;
      _mulaiPush();
      return User.fromJson(res['data'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      await jeda;
      if (e.isUnauthorized || e.statusCode == 403) {
        await _tokens.clear();
        return null;
      }
      rethrow; // offline / server error → tampilkan tombol coba lagi
    }
  }

  Future<void> login(String username, String password) async {
    final res = await _api.post('/login', data: {
      'username': username.trim(),
      'password': password,
      'device_name': 'portal-salaf-app',
    });

    await _tokens.write(res['token'] as String);
    state = AsyncData(User.fromJson(res['user'] as Map<String, dynamic>));
    _mulaiPush();
  }

  /// Daftarkan perangkat untuk push notification (tidak menunggu, tidak menggagalkan login).
  void _mulaiPush() => unawaited(Future(() => ref.read(pushServiceProvider).mulai()));

  /// Ganti foto profil pengurus yang sedang login.
  Future<void> gantiFoto(UploadFile foto) async {
    final res = await _api.upload('/me/foto', {'foto': foto});
    state = AsyncData(User.fromJson(res['data'] as Map<String, dynamic>));
  }

  Future<void> hapusFoto() async {
    final res = await _api.delete('/me/foto');
    state = AsyncData(User.fromJson(res['data'] as Map<String, dynamic>));
  }

  /// Muat ulang profil (misal setelah data diubah).
  Future<void> refreshUser() async {
    final res = await _api.get('/me');
    state = AsyncData(User.fromJson(res['data'] as Map<String, dynamic>));
  }

  Future<void> logout() async {
    try {
      // Sertakan token perangkat supaya server berhenti mengirim push ke HP ini
      final deviceToken = ref.read(pushServiceProvider).token;
      await _api.post('/logout', data: {'device_token': ?deviceToken});
    } catch (_) {
      // Tetap keluar meskipun server tidak bisa dihubungi
    }
    await _tokens.clear();
    state = const AsyncData(null);
  }

  void _sesiBerakhir() {
    if (state.value == null) return;
    _tokens.clear();
    state = const AsyncData(null);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, User?>(AuthController.new);
