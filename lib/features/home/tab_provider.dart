import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tab yang sedang dibuka di menu bawah, supaya halaman lain bisa berpindah tab
/// (misalnya dari beranda santri langsung ke tab Tagihan).
class TabAktif extends Notifier<int> {
  @override
  int build() => 0;

  void pilih(int index) => state = index;
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
