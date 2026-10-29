import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../models/keuangan.dart';
import '../../models/santri.dart';

class KeuanganRepository {
  KeuanganRepository(this._api);

  final ApiClient _api;

  // --- Jenis tagihan -------------------------------------------------------

  Future<List<JenisTagihan>> jenisTagihan({String? tipe, bool? aktif}) async {
    final res = await _api.get('/jenis-tagihan', query: {'tipe': ?tipe, if (aktif != null) 'aktif': aktif ? 1 : 0});
    return (res['data'] as List).map((e) => JenisTagihan.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> simpanJenisTagihan({int? id, required String nama, String? tipe, required int nominal, bool? aktif}) async {
    if (id == null) {
      await _api.post('/jenis-tagihan', data: {'nama': nama, 'tipe': tipe, 'nominal': nominal});
    } else {
      await _api.put('/jenis-tagihan/$id', data: {'nama': nama, 'nominal': nominal, 'is_active': ?aktif});
    }
  }

  Future<String> hapusJenisTagihan(int id) async => (await _api.delete('/jenis-tagihan/$id'))['message'] as String;

  // --- Tagihan --------------------------------------------------------------

  Future<({Halaman<Tagihan> halaman, RingkasanTagihan ringkasan})> tagihan({
    int page = 1,
    String? status,
    bool belumLunas = false,
    int? santriId,
    String? search,
    String? gender,
  }) async {
    final res = await _api.get('/tagihan', query: {
      'page': page,
      'status': ?status,
      if (belumLunas) 'belum_lunas': 1,
      'santri_id': ?santriId,
      if (search != null && search.isNotEmpty) 'search': search,
      'gender': ?gender,
    });
    return (
      halaman: Halaman.fromJson(res, Tagihan.fromJson),
      ringkasan: RingkasanTagihan.fromJson(res['ringkasan'] as Map<String, dynamic>?),
    );
  }

  Future<Tagihan> detailTagihan(int id) async {
    final res = await _api.get('/tagihan/$id');
    return Tagihan.fromJson(res['data'] as Map<String, dynamic>);
  }

  /// Buat iuran untuk santri aktif (semua sesuai gender, atau hanya [santriIds]). Mengembalikan pesan dari server.
  Future<String> buatIuran({
    required int jenisTagihanId,
    String? judul,
    int? nominal,
    String? jatuhTempo,
    String? gender,
    List<int>? santriIds,
  }) async {
    final res = await _api.post('/tagihan', data: {
      'jenis_tagihan_id': jenisTagihanId,
      if (judul != null && judul.isNotEmpty) 'judul': judul,
      'nominal': ?nominal,
      'jatuh_tempo': ?jatuhTempo,
      'gender': ?gender,
      'santri_ids': ?santriIds,
    });
    return res['message'] as String;
  }

  Future<String> generateSpp({String? periode}) async =>
      (await _api.post('/tagihan/generate-spp', data: {'periode': ?periode}))['message'] as String;

  // --- Keringanan SPP --------------------------------------------------------

  Future<List<KeringananSpp>> keringananSpp(int santriId) async {
    final res = await _api.get('/santri/$santriId/keringanan-spp');
    return (res['data'] as List).map((e) => KeringananSpp.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Simpan keringanan baru (id null) atau ubah yang ada. Mengembalikan pesan dari server.
  Future<String> simpanKeringananSpp({
    int? id,
    required int santriId,
    required int nominal,
    required String mulai,
    String? sampai,
    String? keterangan,
  }) async {
    final data = {'nominal': nominal, 'mulai': mulai, 'sampai': sampai, 'keterangan': keterangan};
    final res = id == null ? await _api.post('/santri/$santriId/keringanan-spp', data: data) : await _api.put('/keringanan-spp/$id', data: data);
    return res['message'] as String;
  }

  Future<String> hapusKeringananSpp(int id) async => (await _api.delete('/keringanan-spp/$id'))['message'] as String;

  Future<void> ubahTagihan(int id, {required String judul, required int nominal, String? jatuhTempo}) =>
      _api.put('/tagihan/$id', data: {'judul': judul, 'nominal': nominal, 'jatuh_tempo': jatuhTempo});

  Future<void> hapusTagihan(int id) => _api.delete('/tagihan/$id');

  // --- Pembayaran -----------------------------------------------------------

  Future<Halaman<Pembayaran>> pembayaran({int page = 1, String? status, int? santriId}) async {
    final res = await _api.get('/pembayaran', query: {'page': page, 'status': ?status, 'santri_id': ?santriId});
    return Halaman.fromJson(res, Pembayaran.fromJson);
  }

  Future<Pembayaran> detailPembayaran(int id) async {
    final res = await _api.get('/pembayaran/$id');
    return Pembayaran.fromJson(res['data'] as Map<String, dynamic>);
  }

  /// Santri: unggah bukti. Bendahara/admin: catat pembayaran langsung (bukti opsional).
  Future<String> bayar({
    required int tagihanId,
    required int nominal,
    String? metode,
    String? tanggalBayar,
    String? catatan,
    UploadFile? bukti,
  }) async {
    final res = await _api.upload('/pembayaran', {
      'tagihan_id': tagihanId,
      'nominal': nominal,
      'metode': metode,
      'tanggal_bayar': tanggalBayar,
      'catatan': (catatan?.isEmpty ?? true) ? null : catatan,
      'bukti': bukti,
    });
    return res['message'] as String? ?? 'Pembayaran tersimpan.';
  }

  Future<void> setujui(int id) => _api.post('/pembayaran/$id/setujui');

  Future<void> tolak(int id, String alasan) => _api.post('/pembayaran/$id/tolak', data: {'alasan': alasan});

  // --- Kas ------------------------------------------------------------------

  Future<SaldoKas> saldo() async => SaldoKas.fromJson((await _api.get('/kas/saldo'))['data'] as Map<String, dynamic>);

  Future<Halaman<KasTransaksi>> kas({int page = 1, String? tipe, String? gender, String? dari, String? sampai}) async {
    final res = await _api.get('/kas', query: {
      'page': page,
      'tipe': ?tipe,
      'gender': ?gender,
      'dari': ?dari,
      'sampai': ?sampai,
    });
    return Halaman.fromJson(res, KasTransaksi.fromJson);
  }

  Future<void> catatKas({
    required String tipe,
    required int kategoriId,
    required int nominal,
    required String keterangan,
    String? tanggal,
    String? gender,
    UploadFile? bukti,
  }) =>
      _api.upload('/kas', {
        'tipe': tipe,
        'kategori_kas_id': kategoriId,
        'nominal': nominal,
        'keterangan': keterangan,
        'tanggal': tanggal,
        'gender': gender,
        'bukti': bukti,
      });

  Future<void> hapusKas(int id) => _api.delete('/kas/$id');

  Future<List<KategoriKas>> kategoriKas({String? tipe}) async {
    final res = await _api.get('/kategori-kas', query: {'tipe': ?tipe});
    return (res['data'] as List).map((e) => KategoriKas.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> simpanKategoriKas({int? id, required String nama, String? tipe}) async {
    if (id == null) {
      await _api.post('/kategori-kas', data: {'nama': nama, 'tipe': tipe});
    } else {
      await _api.put('/kategori-kas/$id', data: {'nama': nama});
    }
  }

  Future<void> hapusKategoriKas(int id) => _api.delete('/kategori-kas/$id');

  // --- Laporan --------------------------------------------------------------

  Future<Map<String, dynamic>> laporanKeuangan({required String dari, required String sampai, String? gender}) async {
    final res = await _api.get('/laporan/keuangan', query: {'dari': dari, 'sampai': sampai, 'gender': ?gender});
    return res['data'] as Map<String, dynamic>;
  }

  Future<Halaman<Map<String, dynamic>>> tunggakan({int page = 1, String? search, String? gender}) async {
    final res = await _api.get('/laporan/tunggakan', query: {
      'page': page,
      if (search != null && search.isNotEmpty) 'search': search,
      'gender': ?gender,
    });
    return Halaman.fromJson(res, (m) => m);
  }
}

final keuanganRepositoryProvider = Provider((ref) => KeuanganRepository(ref.watch(apiClientProvider)));

final saldoKasProvider = FutureProvider.autoDispose((ref) => ref.watch(keuanganRepositoryProvider).saldo());

final jenisTagihanProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(keuanganRepositoryProvider).jenisTagihan(),
);

final kategoriKasProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(keuanganRepositoryProvider).kategoriKas(),
);

final tagihanDetailProvider = FutureProvider.autoDispose.family<Tagihan, int>(
  (ref, id) => ref.watch(keuanganRepositoryProvider).detailTagihan(id),
);

final keringananSppProvider = FutureProvider.autoDispose.family<List<KeringananSpp>, int>(
  (ref, santriId) => ref.watch(keuanganRepositoryProvider).keringananSpp(santriId),
);

final pembayaranDetailProvider = FutureProvider.autoDispose.family<Pembayaran, int>(
  (ref, id) => ref.watch(keuanganRepositoryProvider).detailPembayaran(id),
);

/// Jumlah pembayaran yang menunggu verifikasi (untuk lencana menu).
final jumlahMenungguProvider = FutureProvider.autoDispose<int>((ref) async {
  final h = await ref.watch(keuanganRepositoryProvider).pembayaran(status: 'menunggu');
  return h.total;
});
