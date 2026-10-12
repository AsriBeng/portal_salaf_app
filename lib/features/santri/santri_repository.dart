import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../models/kartu.dart';
import '../../models/santri.dart';

class SantriRepository {
  SantriRepository(this._api);

  final ApiClient _api;

  Future<Halaman<Santri>> daftar({
    int page = 1,
    String? search,
    String status = 'aktif',
    String? gender,
    int? kamarId,
  }) async {
    final res = await _api.get('/santri', query: {
      'page': page,
      'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
      'gender': ?gender,
      'kamar_id': ?kamarId,
    });
    return Halaman.fromJson(res, Santri.fromJson);
  }

  Future<Santri> detail(int id) async {
    final res = await _api.get('/santri/$id');
    return Santri.fromJson(res['data'] as Map<String, dynamic>);
  }

  /// Data lengkap milik santri yang login.
  Future<Santri> saya() async {
    final res = await _api.get('/profil-santri');
    return Santri.fromJson(res['data'] as Map<String, dynamic>);
  }

  /// Tambah (id null) atau ubah santri. Mengembalikan data terbaru.
  Future<Santri> simpan({int? id, required Map<String, dynamic> data}) async {
    final res = await _api.post(id == null ? '/santri' : '/santri/$id', data: data);
    return Santri.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> hapus(int id) => _api.delete('/santri/$id');

  Future<String> resetPassword(int id, {String? password}) async {
    final res = await _api.post('/santri/$id/reset-password', data: {
      if (password != null && password.isNotEmpty) 'password': password,
    });
    return res['message'] as String;
  }

  Future<String> setAktif(int id, bool aktif) async {
    final res = await _api.post('/santri/$id/aktif', data: {'is_active': aktif});
    return res['message'] as String;
  }

  Future<Santri> uploadDokumen(int id, JenisDokumen jenis, UploadFile file) async {
    final res = await _api.upload('/santri/$id/dokumen', {jenis.key: file});
    return Santri.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<KartuSantri> kartu({int? santriId}) async {
    final res = await _api.get(santriId == null ? '/kartu-saya' : '/santri/$santriId/kartu');
    return KartuSantri.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<KartuSantri> buatQrBaru(int santriId) async {
    final res = await _api.post('/santri/$santriId/kartu/regenerate');
    return KartuSantri.fromJson(res['data'] as Map<String, dynamic>);
  }
}

final santriRepositoryProvider = Provider((ref) => SantriRepository(ref.watch(apiClientProvider)));

final santriDetailProvider = FutureProvider.autoDispose.family<Santri, int>(
  (ref, id) => ref.watch(santriRepositoryProvider).detail(id),
);

/// Data diri santri yang login.
final santriSayaProvider = FutureProvider.autoDispose<Santri>(
  (ref) => ref.watch(santriRepositoryProvider).saya(),
);

/// Kartu santri. null = kartu milik santri yang login.
final kartuProvider = FutureProvider.autoDispose.family<KartuSantri, int?>(
  (ref, santriId) => ref.watch(santriRepositoryProvider).kartu(santriId: santriId),
);
