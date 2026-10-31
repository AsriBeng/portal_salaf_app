import 'package:adhan/adhan.dart';
// SolarTime dipakai langsung supaya sudut tiap waktu (termasuk dhuha) bisa mengikuti kriteria Kemenag
// ignore: implementation_imports
import 'package:adhan/src/internal/shadow_length.dart';
// ignore: implementation_imports
import 'package:adhan/src/internal/solar_time.dart';

/// Waktu-waktu dalam satu hari, urut dari imsak sampai isya.
enum Waktu {
  imsak('Imsak'),
  subuh('Subuh'),
  terbit('Terbit'),
  dhuha('Dhuha'),
  dzuhur('Dzuhur'),
  ashar('Ashar'),
  maghrib('Maghrib'),
  isya('Isya');

  const Waktu(this.label);
  final String label;

  /// Imsak, terbit, dan dhuha hanya penanda, bukan sholat wajib.
  bool get wajib => this == subuh || this == dzuhur || this == ashar || this == maghrib || this == isya;
}

/// Jadwal satu hari untuk satu lokasi, dihitung dengan kriteria Kemenag RI:
/// subuh 20° & isya 18° di bawah ufuk, ashar bayangan 1× (Syafi'i), dhuha matahari 4,5° di atas ufuk,
/// imsak 10 menit sebelum subuh, ihtiyat 2 menit, dan menit dibulatkan ke atas
/// (terbit dibulatkan ke bawah dan dikurangi ihtiyat supaya aman).
class JadwalSholat {
  JadwalSholat._(this.tanggal, this.waktu);

  /// Tanggal (waktu lokal perangkat) yang dihitung.
  final DateTime tanggal;
  final Map<Waktu, DateTime> waktu;

  DateTime operator [](Waktu w) => waktu[w]!;

  static const _ihtiyat = 2;

  /// Tinggi matahari saat terbit/terbenam: jari-jari piringan + refraksi + kerendahan ufuk.
  static const _ufuk = -1.0;

  factory JadwalSholat.hitung({required double lintang, required double bujur, required DateTime tanggal}) {
    final hari = DateTime(tanggal.year, tanggal.month, tanggal.day);
    final utc = DateTime.utc(hari.year, hari.month, hari.day);
    final matahari = SolarTime(utc, Coordinates(lintang, bujur));

    // jam desimal UTC -> DateTime lokal, dibulatkan per menit
    DateTime jam(double nilai, {int tambah = _ihtiyat, bool keAtas = true}) {
      final detik = (nilai * 3600).round() + tambah * 60;
      final menit = keAtas ? (detik / 60).ceil() : (detik / 60).floor();
      return utc.add(Duration(minutes: menit)).toLocal();
    }

    final subuh = jam(matahari.hourAngle(-20, false));
    final ashar = matahari.afternoon(ShadowLength.single);

    return JadwalSholat._(hari, {
      Waktu.imsak: subuh.subtract(const Duration(minutes: 10)),
      Waktu.subuh: subuh,
      Waktu.terbit: jam(matahari.hourAngle(_ufuk, false), tambah: -_ihtiyat, keAtas: false),
      Waktu.dhuha: jam(matahari.hourAngle(4.5, false)),
      // dzuhur diberi ihtiyat lebih supaya pasti sudah lewat zawal
      Waktu.dzuhur: jam(matahari.transit, tambah: _ihtiyat + 1),
      Waktu.ashar: jam(ashar),
      Waktu.maghrib: jam(matahari.hourAngle(_ufuk, true)),
      Waktu.isya: jam(matahari.hourAngle(-18, true)),
    });
  }

  /// Waktu berikutnya setelah [sekarang] dari jadwal hari ini, atau null jika isya sudah lewat.
  MapEntry<Waktu, DateTime>? berikutnya(DateTime sekarang, {bool hanyaWajib = false}) {
    for (final e in waktu.entries) {
      if (hanyaWajib && !e.key.wajib) continue;
      if (e.value.isAfter(sekarang)) return e;
    }
    return null;
  }
}
