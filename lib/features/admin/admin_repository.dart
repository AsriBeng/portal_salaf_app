import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../models/santri.dart';
import '../../models/user.dart';

/// Akun pengurus beserta status aktifnya.
class Pengurus {
  const Pengurus({required this.user, required this.aktif});

  final User user;
  final bool aktif;

  factory Pengurus.fromJson(Map<String, dynamic> json) =>
      Pengurus(user: User.fromJson(json), aktif: json['is_active'] as bool? ?? true);
}

class AdminRepository {
  AdminRepository(this._api);

  final ApiClient _api;

  Future<Halaman<Pengurus>> pengurus({int page = 1, String? role, String? search}) async {
    final res = await _api.get('/users', query: {
      'page': page,
      'role': ?role,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return Halaman.fromJson(res, Pengurus.fromJson);
  }

  Future<void> simpanPengurus({
    int? id,
    required String name,
    required String username,
    String? password,
    required String role,
    String? gender,
    String? phone,
    bool? aktif,
  }) async {
    final data = {
      'name': name,
      'username': username,
      'role': role,
      'gender': role == 'admin' ? null : gender,
      'phone': phone,
      if (id == null) 'password': password,
      'is_active': ?aktif,
    };
    if (id == null) {
      await _api.post('/users', data: data);
    } else {
      await _api.put('/users/$id', data: data);
    }
  }

  Future<void> resetPassword(int id, String password) => _api.post('/users/$id/reset-password', data: {'password': password});

  Future<void> nonaktifkan(int id) => _api.delete('/users/$id');

  Future<Map<String, dynamic>> pengaturan() async => (await _api.get('/settings'))['data'] as Map<String, dynamic>;

  Future<Map<String, dynamic>> simpanPengaturan(Map<String, Object?> data, {UploadFile? logo}) async {
    final res = await _api.upload('/settings', {...data, 'logo': logo});
    return res['data'] as Map<String, dynamic>;
  }
}

final adminRepositoryProvider = Provider((ref) => AdminRepository(ref.watch(apiClientProvider)));
