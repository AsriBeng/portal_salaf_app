/// Data kartu santri dari GET /kartu-saya atau /santri/{id}/kartu.
class KartuSantri {
  const KartuSantri({
    required this.pondokNama,
    required this.pondokAlamat,
    required this.logoUrl,
    required this.santriId,
    required this.nis,
    required this.namaLengkap,
    required this.jenisKelamin,
    required this.ttl,
    required this.alamat,
    required this.status,
    required this.berlaku,
    required this.qrUrl,
    this.fotoUrl,
    this.tanggalKeluar,
  });

  final String pondokNama;
  final String pondokAlamat;
  final String? logoUrl;
  final int santriId;
  final String nis;
  final String namaLengkap;
  final String jenisKelamin;
  final String ttl;
  final String alamat;
  final String status;
  final String berlaku;
  final String qrUrl;
  final String? fotoUrl;

  /// Tanggal lulus / keluar (yyyy-mm-dd), null jika masih aktif
  final String? tanggalKeluar;

  bool get aktif => status == 'aktif';
  bool get lulus => status == 'lulus';
  bool get keluar => status == 'keluar';

  factory KartuSantri.fromJson(Map<String, dynamic> json) {
    final pondok = json['pondok'] as Map<String, dynamic>;
    final santri = json['santri'] as Map<String, dynamic>;
    return KartuSantri(
      pondokNama: pondok['nama'] as String? ?? '',
      pondokAlamat: pondok['alamat'] as String? ?? '',
      logoUrl: pondok['logo_url'] as String?,
      santriId: santri['id'] as int,
      nis: santri['nis'] as String,
      namaLengkap: santri['nama_lengkap'] as String,
      jenisKelamin: santri['jenis_kelamin'] as String,
      ttl: santri['ttl'] as String? ?? '',
      alamat: santri['alamat'] as String? ?? '',
      fotoUrl: santri['foto_url'] as String?,
      status: json['status'] as String,
      berlaku: json['berlaku'] as String? ?? '',
      qrUrl: json['qr_url'] as String,
      tanggalKeluar: json['tanggal_keluar'] as String?,
    );
  }
}
