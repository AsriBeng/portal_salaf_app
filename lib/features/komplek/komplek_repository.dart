import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../models/komplek.dart';
import '../../models/santri.dart';

class KomplekRepository {
  KomplekRepository(this._api);

  final ApiClient _api;

  Future<List<Komplek>> daftarKomplek({String? gender}) async {
    final res = await _api.get('/komplek', query: {'gender': ?gender});
    return (res['data'] as List).map((e) => Komplek.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Komplek> detailKomplek(int id) async {
    final res = await _api.get('/komplek/$id');
    return Komplek.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> simpanKomplek({int? id, required String nama, String? keterangan, String? gender}) async {
    final data = {'nama': nama, 'keterangan': keterangan, 'gender': ?gender};
    if (id == null) {
      await _api.post('/komplek', data: data);
    } else {
      await _api.put('/komplek/$id', data: data);
    }
  }

  Future<void> hapusKomplek(int id) => _api.delete('/komplek/$id');

  /// Daftar kamar. `tersedia` = hanya kamar yang masih ada tempat.
  Future<List<Kamar>> daftarKamar({String? gender, int? komplekId, bool tersedia = false}) async {
    final res = await _api.get('/kamar', query: {
      'gender': ?gender,
      'komplek_id': ?komplekId,
      if (tersedia) 'tersedia': 1,
    });
    return (res['data'] as List).map((e) => Kamar.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<({Kamar kamar, List<Santri> penghuni})> detailKamar(int id) async {
    final res = await _api.get('/kamar/$id');
    return (
      kamar: Kamar.fromJson(res['data'] as Map<String, dynamic>),
      penghuni: (res['santri'] as List).map((e) => Santri.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Future<void> simpanKamar({int? id, required int komplekId, required String nama, required int kapasitas}) async {
    if (id == null) {
      await _api.post('/kamar', data: {'komplek_id': komplekId, 'nama': nama, 'kapasitas': kapasitas});
    } else {
      await _api.put('/kamar/$id', data: {'nama': nama, 'kapasitas': kapasitas});
    }
  }

  Future<void> hapusKamar(int id) => _api.delete('/kamar/$id');
}

final komplekRepositoryProvider = Provider((ref) => KomplekRepository(ref.watch(apiClientProvider)));

/// Daftar komplek, difilter gender (admin). null = semua.
final komplekListProvider = FutureProvider.autoDispose.family<List<Komplek>, String?>(
  (ref, gender) => ref.watch(komplekRepositoryProvider).daftarKomplek(gender: gender),
);

final komplekDetailProvider = FutureProvider.autoDispose.family<Komplek, int>(
  (ref, id) => ref.watch(komplekRepositoryProvider).detailKomplek(id),
);

final kamarDetailProvider = FutureProvider.autoDispose.family<({Kamar kamar, List<Santri> penghuni}), int>(
  (ref, id) => ref.watch(komplekRepositoryProvider).detailKamar(id),
);

/// Pilihan kamar di form santri (sesuai gender santri).
final kamarPilihanProvider = FutureProvider.autoDispose.family<List<Kamar>, String?>(
  (ref, gender) => ref.watch(komplekRepositoryProvider).daftarKamar(gender: gender),
);
