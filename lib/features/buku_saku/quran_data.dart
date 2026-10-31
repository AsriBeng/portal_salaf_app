import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Huruf Arab mushaf standar Indonesia (LPMQ Isep Misbah, Kemenag).
const fontQuran = 'LPMQ';

class Surat {
  const Surat({
    required this.nomor,
    required this.nama,
    required this.latin,
    required this.arti,
    required this.jumlahAyat,
    required this.tempat,
  });

  final int nomor;
  final String nama;
  final String latin;
  final String arti;
  final int jumlahAyat;
  final String tempat;

  /// Al-Fatihah (basmalah = ayat 1) dan At-Taubah tidak diberi basmalah terpisah.
  bool get pakaiBasmalah => nomor != 1 && nomor != 9;

  String get golongan => tempat == 'Mekah' ? 'Makkiyah' : 'Madaniyah';
}

/// Satu ayat: nomor surat & ayat, dan urutannya dari 0 sampai 6235.
class Ayat {
  const Ayat(this.surat, this.ayat, this.indeks);

  final int surat;
  final int ayat;
  final int indeks;
}

/// Teks Arab Kemenag (via EQuran.id) beserta pembagian juz dan 604 halaman mushaf Madinah (Tanzil).
/// Semua dibaca dari aset aplikasi, tanpa internet.
class QuranData {
  QuranData._(this.surat, this._arab, List<List<int>> halaman, List<List<int>> juz) {
    var jumlah = 0;
    for (final s in surat) {
      _awalSurat.add(jumlah);
      jumlah += s.jumlahAyat;
    }
    _awalHalaman = [for (final h in halaman) indeks(h[0], h[1])];
    _awalJuz = [for (final j in juz) indeks(j[0], j[1])];
  }

  static const jumlahAyat = 6236;
  static const jumlahHalaman = 604;

  final List<Surat> surat;
  final List<List<String>> _arab;
  final _awalSurat = <int>[];
  late final List<int> _awalHalaman;
  late final List<int> _awalJuz;

  String arab(int surat, int ayat) => _arab[surat - 1][ayat - 1];

  /// Basmalah sama persis dengan Al-Fatihah ayat 1.
  String get basmalah => arab(1, 1);

  int indeks(int surat, int ayat) => _awalSurat[surat - 1] + ayat - 1;

  Ayat ayat(int indeks) {
    final s = _cari(_awalSurat, indeks);
    return Ayat(s + 1, indeks - _awalSurat[s] + 1, indeks);
  }

  /// Halaman 1–604 tempat ayat ini berada.
  int halaman(int indeks) => _cari(_awalHalaman, indeks) + 1;

  /// Juz 1–30 tempat ayat ini berada.
  int juz(int indeks) => _cari(_awalJuz, indeks) + 1;

  /// Rentang indeks ayat [awal, akhir) untuk satu halaman, surat, atau juz.
  (int, int) rentangHalaman(int halaman) => (_awalHalaman[halaman - 1], halaman < jumlahHalaman ? _awalHalaman[halaman] : jumlahAyat);
  (int, int) rentangSurat(int surat) => (_awalSurat[surat - 1], surat < 114 ? _awalSurat[surat] : jumlahAyat);
  (int, int) rentangJuz(int juz) => (_awalJuz[juz - 1], juz < 30 ? _awalJuz[juz] : jumlahAyat);

  /// Posisi terakhir yang <= [nilai] pada daftar awal yang terurut.
  static int _cari(List<int> awal, int nilai) {
    var lo = 0;
    var hi = awal.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (awal[mid] <= nilai) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  static Future<QuranData> muat() async {
    final teks = await Future.wait([
      for (final f in ['surat', 'arab', 'halaman', 'juz']) rootBundle.loadString('assets/quran/$f.json'),
    ]);
    final (surat, arab, halaman, juz) = await compute(_urai, teks);
    return QuranData._(surat, arab, halaman, juz);
  }

  static (List<Surat>, List<List<String>>, List<List<int>>, List<List<int>>) _urai(List<String> teks) {
    final surat = [
      for (final (i, s) in (jsonDecode(teks[0]) as List).indexed)
        Surat(nomor: i + 1, nama: s[0], latin: s[1], arti: s[2], jumlahAyat: s[3], tempat: s[4]),
    ];
    List<List<T>> daftar<T>(String json) => [for (final x in jsonDecode(json) as List) (x as List).cast<T>()];
    return (surat, daftar<String>(teks[1]), daftar<int>(teks[2]), daftar<int>(teks[3]));
  }
}

final quranProvider = FutureProvider<QuranData>((ref) => QuranData.muat());

/// Terjemahan Kemenag per surat, dimuat terpisah karena hanya dipakai mode terjemah.
final terjemahProvider = FutureProvider<List<List<String>>>((ref) async {
  final teks = await rootBundle.loadString('assets/quran/terjemah.json');
  return compute((String t) => [for (final x in jsonDecode(t) as List) (x as List).cast<String>()], teks);
});

/// Angka Arab (١٢٣) untuk nomor ayat dan halaman.
String angkaArab(int n) => n.toString().split('').map((c) => '٠١٢٣٤٥٦٧٨٩'[int.parse(c)]).join();

// --- Terakhir dibaca & ukuran huruf ------------------------------------------

enum ModeQuran { mushaf, terjemah }

class PosisiBaca {
  const PosisiBaca(this.mode, this.indeks);

  final ModeQuran mode;

  /// Indeks ayat (0–6235); untuk mushaf: ayat pertama di halaman.
  final int indeks;
}

class PengaturanQuran {
  const PengaturanQuran({this.mushaf, this.terjemah, this.modeTerakhir, this.ukuranHuruf = 26});

  final PosisiBaca? mushaf;
  final PosisiBaca? terjemah;
  final ModeQuran? modeTerakhir;
  final double ukuranHuruf;

  /// Posisi dari mode yang terakhir dibuka.
  PosisiBaca? get terakhir => modeTerakhir == ModeQuran.mushaf ? mushaf : terjemah;

  PengaturanQuran salin({PosisiBaca? posisi, double? ukuranHuruf}) => PengaturanQuran(
    mushaf: posisi?.mode == ModeQuran.mushaf ? posisi : mushaf,
    terjemah: posisi?.mode == ModeQuran.terjemah ? posisi : terjemah,
    modeTerakhir: posisi?.mode ?? modeTerakhir,
    ukuranHuruf: ukuranHuruf ?? this.ukuranHuruf,
  );
}

class PengaturanQuranController extends AsyncNotifier<PengaturanQuran> {
  static const _kunci = {ModeQuran.mushaf: 'quran_mushaf', ModeQuran.terjemah: 'quran_terjemah'};
  static const _ukuran = 'quran_ukuran';
  static const _terakhir = 'quran_terakhir';

  @override
  Future<PengaturanQuran> build() async {
    final p = await SharedPreferences.getInstance();
    PosisiBaca? posisi(ModeQuran m) => switch (p.getInt(_kunci[m]!)) {
      final int i => PosisiBaca(m, i),
      null => null,
    };
    return PengaturanQuran(
      mushaf: posisi(ModeQuran.mushaf),
      terjemah: posisi(ModeQuran.terjemah),
      modeTerakhir: ModeQuran.values.where((m) => m.name == p.getString(_terakhir)).firstOrNull,
      ukuranHuruf: p.getDouble(_ukuran) ?? 26,
    );
  }

  Future<void> simpanPosisi(ModeQuran mode, int indeks) async {
    final posisi = PosisiBaca(mode, indeks);
    state = AsyncData((state.value ?? const PengaturanQuran()).salin(posisi: posisi));
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kunci[mode]!, indeks);
    await p.setString(_terakhir, mode.name);
  }

  Future<void> ubahUkuran(double ukuran) async {
    final nilai = ukuran.clamp(18, 40).toDouble();
    state = AsyncData((state.value ?? const PengaturanQuran()).salin(ukuranHuruf: nilai));
    await (await SharedPreferences.getInstance()).setDouble(_ukuran, nilai);
  }
}

final pengaturanQuranProvider = AsyncNotifierProvider<PengaturanQuranController, PengaturanQuran>(PengaturanQuranController.new);
