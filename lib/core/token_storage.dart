import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Token login disimpan terenkripsi (Keychain di iOS, Keystore di Android).
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'auth_token';
  final FlutterSecureStorage _storage;

  /// Disimpan juga di memori supaya interceptor tidak membaca storage di setiap request.
  String? _cache;

  Future<String?> read() async => _cache ??= await _storage.read(key: _key);

  Future<void> write(String token) async {
    _cache = token;
    await _storage.write(key: _key, value: token);
  }

  Future<void> clear() async {
    _cache = null;
    await _storage.delete(key: _key);
  }

  /// Token saat ini tanpa await (untuk header gambar).
  String? get current => _cache;
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());
