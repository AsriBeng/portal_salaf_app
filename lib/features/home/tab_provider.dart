import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user.dart';

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

/// Tab di menu bawah.
enum MenuTab { beranda, santri, kamar, keuangan, kartu, tagihan, profil }

/// Urutan tab di menu bawah sesuai peran.
List<MenuTab> urutanTab(Role role) => switch (role) {
      // Urutan harus sama dengan TabSantri
      Role.santri => const [MenuTab.beranda, MenuTab.kartu, MenuTab.tagihan, MenuTab.profil],
      Role.sekretaris => const [MenuTab.beranda, MenuTab.santri, MenuTab.kamar, MenuTab.profil],
      Role.bendahara => const [MenuTab.beranda, MenuTab.keuangan, MenuTab.santri, MenuTab.profil],
      Role.admin || Role.ketua => const [MenuTab.beranda, MenuTab.santri, MenuTab.kamar, MenuTab.keuangan, MenuTab.profil],
    };

/// Urutan tab santri di menu bawah.
class TabSantri {
  TabSantri._();

  static const beranda = 0;
  static const kartu = 1;
  static const tagihan = 2;
  static const profil = 3;
}
