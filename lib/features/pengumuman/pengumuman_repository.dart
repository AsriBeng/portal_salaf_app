import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../models/pengumuman.dart';
import '../../models/santri.dart';

class PengumumanRepository {
  PengumumanRepository(this._api);

  final ApiClient _api;

  Future<Halaman<Pengumuman>> daftar({int page = 1, String? search}) async {
    final res = await _api.get('/pengumuman', query: {
      'page': page,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return Halaman.fromJson(res, Pengumuman.fromJson);
  }

  Future<Pengumuman> detail(int id) async {
    final res = await _api.get('/pengumuman/$id');
    return Pengumuman.fromJson(res['data'] as Map<String, dynamic>);
  }

  /// Buat (id null) atau ubah pengumuman. Lampiran opsional (gambar / PDF).
  Future<Pengumuman> simpan({
    int? id,
    required String judul,
    required String isi,
    required String target,
    UploadFile? lampiran,
    bool hapusLampiran = false,
  }) async {
    final res = await _api.upload(id == null ? '/pengumuman' : '/pengumuman/$id', {
      'judul': judul,
      'isi': isi,
      'target': target,
      'lampiran': lampiran,
      if (hapusLampiran) 'hapus_lampiran': 1,
    });
    return Pengumuman.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> hapus(int id) => _api.delete('/pengumuman/$id');

  // --- Notifikasi -------------------------------------------------------------

  Future<({Halaman<Notifikasi> halaman, int belumDibaca})> notifikasi({int page = 1, bool belumDibaca = false}) async {
    final res = await _api.get('/notifikasi', query: {'page': page, if (belumDibaca) 'belum_dibaca': 1});
    return (
      halaman: Halaman.fromJson(res, Notifikasi.fromJson),
      belumDibaca: (res['belum_dibaca'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> tandaiDibaca(String id) => _api.post('/notifikasi/$id/baca');

  Future<void> tandaiSemuaDibaca() => _api.post('/notifikasi/baca-semua');
}

final pengumumanRepositoryProvider = Provider((ref) => PengumumanRepository(ref.watch(apiClientProvider)));

final pengumumanDetailProvider = FutureProvider.autoDispose.family<Pengumuman, int>(
  (ref, id) => ref.watch(pengumumanRepositoryProvider).detail(id),
);

/// Jumlah notifikasi belum dibaca (lencana lonceng).
final notifBelumDibacaProvider = FutureProvider.autoDispose<int>((ref) async {
  final hasil = await ref.watch(pengumumanRepositoryProvider).notifikasi(belumDibaca: true);
  return hasil.belumDibaca;
});
