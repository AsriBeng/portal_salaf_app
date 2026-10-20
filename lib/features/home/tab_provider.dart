import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tab yang sedang dibuka di menu bawah, supaya halaman lain bisa berpindah tab
/// (misalnya dari beranda santri langsung ke tab Tagihan).
class TabAktif extends Notifier<int> {
  /// Tab yang pernah dibuka sebelumnya, untuk tombol kembali di HP.
  final _riwayat = <int>[];

  @override
  int build() {
    _riwayat.clear();
    return 0;
  }

  void pilih(int index) {
    if (index == state) return;
    _riwayat
      ..remove(index)
      ..remove(state)
      ..add(state);
    state = index;
  }

  /// Masih ada tab yang bisa dituju saat tombol kembali ditekan?
  /// Kalau tidak ada riwayat, kembali ke Beranda dulu sebelum keluar aplikasi.
  bool get bisaKembali => _riwayat.isNotEmpty || state != 0;

  void kembali() {
    if (_riwayat.isNotEmpty) {
      state = _riwayat.removeLast();
    } else if (state != 0) {
      state = 0;
    }
  }
}

// autoDispose: kembali ke Beranda setiap kali login ulang
final tabAktifProvider = NotifierProvider.autoDispose<TabAktif, int>(TabAktif.new);

/// Urutan tab santri di menu bawah.
class TabSantri {
  TabSantri._();

  static const beranda = 0;
  static const kartu = 1;
  static const tagihan = 2;
  static const profil = 3;
}
