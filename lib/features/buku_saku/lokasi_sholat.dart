import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lokasi untuk menghitung jadwal sholat. Disimpan di perangkat dan hanya berubah
/// saat pengguna menekan "Perbarui lokasi".
class LokasiSholat {
  const LokasiSholat({required this.lintang, required this.bujur, required this.nama, this.diperbarui});

  /// Lokasi bawaan sebelum GPS dipakai: Kab. Jombang.
  static const bawaan = LokasiSholat(lintang: -7.55, bujur: 112.23, nama: 'Jombang (bawaan)');

  final double lintang;
  final double bujur;
  final String nama;

  /// Kapan lokasi terakhir diambil dari GPS; null = masih lokasi bawaan.
  final DateTime? diperbarui;
}

class LokasiSholatController extends AsyncNotifier<LokasiSholat> {
  static const _kunci = 'lokasi_sholat';

  @override
  Future<LokasiSholat> build() async {
    final simpan = (await SharedPreferences.getInstance()).getStringList(_kunci);
    if (simpan == null || simpan.length < 4) return LokasiSholat.bawaan;
    return LokasiSholat(
      lintang: double.parse(simpan[0]),
      bujur: double.parse(simpan[1]),
      nama: simpan[2],
      diperbarui: DateTime.tryParse(simpan[3]),
    );
  }

  /// Ambil lokasi dari GPS lalu simpan. Melempar [LokasiGagal] dengan pesan yang bisa ditampilkan.
  Future<LokasiSholat> perbarui() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LokasiGagal('GPS / layanan lokasi belum aktif. Aktifkan dulu lalu coba lagi.');
    }

    var izin = await Geolocator.checkPermission();
    if (izin == LocationPermission.denied) izin = await Geolocator.requestPermission();
    if (izin == LocationPermission.denied || izin == LocationPermission.deniedForever) {
      throw const LokasiGagal('Izin lokasi ditolak. Izinkan akses lokasi untuk aplikasi ini di pengaturan.');
    }

    final posisi = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 20)),
    );

    final lokasi = LokasiSholat(
      lintang: posisi.latitude,
      bujur: posisi.longitude,
      nama: await _namaDaerah(posisi.latitude, posisi.longitude),
      diperbarui: DateTime.now(),
    );

    await (await SharedPreferences.getInstance()).setStringList(_kunci, [
      '${lokasi.lintang}',
      '${lokasi.bujur}',
      lokasi.nama,
      lokasi.diperbarui!.toIso8601String(),
    ]);
    state = AsyncData(lokasi);
    return lokasi;
  }

  /// Nama kecamatan/kota dari koordinat. Di versi web (dan saat tanpa internet) cukup koordinatnya.
  Future<String> _namaDaerah(double lintang, double bujur) async {
    final koordinat = '${lintang.toStringAsFixed(3)}, ${bujur.toStringAsFixed(3)}';
    if (kIsWeb) return koordinat;
    try {
      final p = (await Geocoding(locale: const Locale('id', 'ID')).placemarkFromCoordinates(lintang, bujur)).firstOrNull;
      final nama = [
        p?.subAdministrativeArea ?? p?.locality,
        p?.administrativeArea,
      ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
      return nama.isEmpty ? koordinat : nama;
    } catch (_) {
      return koordinat;
    }
  }
}

class LokasiGagal implements Exception {
  const LokasiGagal(this.pesan);

  final String pesan;

  @override
  String toString() => pesan;
}

final lokasiSholatProvider = AsyncNotifierProvider<LokasiSholatController, LokasiSholat>(LokasiSholatController.new);
