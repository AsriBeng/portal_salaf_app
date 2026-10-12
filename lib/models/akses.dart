import 'user.dart';

/// Hak akses di aplikasi, mengikuti aturan di API.
extension Akses on User {
  bool get bisaLihatKamar => role == Role.admin || role == Role.ketua || role == Role.sekretaris;
  bool get bisaKelolaKamar => role == Role.admin || role == Role.sekretaris;

  bool get bisaKelolaSantri => role == Role.admin || role == Role.sekretaris;
  bool get bisaLihatDokumen => role == Role.admin || role == Role.sekretaris;
  bool get bisaLihatKartu => role == Role.admin || role == Role.ketua || role == Role.sekretaris;

  bool get bisaLihatKeuangan => role == Role.admin || role == Role.ketua || role == Role.bendahara;

  /// Tagihan, verifikasi pembayaran, kas. Ketua hanya bisa melihat.
  bool get bisaKelolaKeuangan => role == Role.admin || role == Role.bendahara;

  bool get bisaBuatPengumuman => role == Role.admin || role == Role.ketua || role == Role.sekretaris;

  /// Pengumuman hanya bisa diubah / dihapus oleh pembuatnya atau admin.
  bool bisaUbahPengumuman(int? pembuatId) => role == Role.admin || (bisaBuatPengumuman && pembuatId == id);
}
