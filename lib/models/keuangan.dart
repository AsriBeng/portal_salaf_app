int _int(Object? v) => (v as num?)?.toInt() ?? 0;

class JenisTagihan {
  const JenisTagihan({required this.id, required this.nama, required this.tipe, required this.nominal, required this.isActive});

  final int id;
  final String nama;

  /// 'spp' atau 'iuran'
  final String tipe;
  final int nominal;
  final bool isActive;

  bool get spp => tipe == 'spp';

  factory JenisTagihan.fromJson(Map<String, dynamic> json) => JenisTagihan(
        id: json['id'] as int,
        nama: json['nama'] as String,
        tipe: json['tipe'] as String,
        nominal: _int(json['nominal']),
        isActive: json['is_active'] as bool? ?? true,
      );
}

enum StatusTagihan {
  belumBayar('belum_bayar', 'Belum bayar'),
  dicicil('dicicil', 'Dicicil'),
  lunas('lunas', 'Lunas');

  const StatusTagihan(this.value, this.label);
  final String value;
  final String label;

  static StatusTagihan parse(String? v) => values.firstWhere((s) => s.value == v, orElse: () => belumBayar);
}

class SantriSingkat {
  const SantriSingkat({required this.id, required this.nis, required this.namaLengkap, required this.jenisKelamin});

  final int id;
  final String nis;
  final String namaLengkap;
  final String jenisKelamin;

  factory SantriSingkat.fromJson(Map<String, dynamic> json) => SantriSingkat(
        id: json['id'] as int,
        nis: json['nis'] as String,
        namaLengkap: json['nama_lengkap'] as String,
        jenisKelamin: json['jenis_kelamin'] as String,
      );
}

class Tagihan {
  const Tagihan({
    required this.id,
    required this.judul,
    required this.nominal,
    required this.terbayar,
    required this.sisa,
    required this.status,
    this.periode,
    this.jatuhTempo,
    this.jenis,
    this.santri,
    this.pembayaran = const [],
  });

  final int id;
  final String judul;
  final int nominal;
  final int terbayar;
  final int sisa;
  final StatusTagihan status;
  final String? periode;
  final String? jatuhTempo;
  final JenisTagihan? jenis;
  final SantriSingkat? santri;
  final List<Pembayaran> pembayaran;

  bool get lunas => status == StatusTagihan.lunas;

  /// Total pembayaran yang masih menunggu verifikasi (hanya terisi di detail tagihan).
  int get menunggu => pembayaran
      .where((p) => p.status == StatusPembayaran.menunggu)
      .fold(0, (total, p) => total + p.nominal);

  /// Nominal maksimal yang masih bisa dibayar sekarang.
  int get bisaDibayar => (sisa - menunggu).clamp(0, sisa);

  bool get lewatJatuhTempo {
    final jt = jatuhTempo == null ? null : DateTime.tryParse(jatuhTempo!);
    return !lunas && jt != null && jt.isBefore(DateTime.now().subtract(const Duration(days: 1)));
  }

  factory Tagihan.fromJson(Map<String, dynamic> json) => Tagihan(
        id: json['id'] as int,
        judul: json['judul'] as String,
        nominal: _int(json['nominal']),
        terbayar: _int(json['terbayar']),
        sisa: _int(json['sisa']),
        status: StatusTagihan.parse(json['status'] as String?),
        periode: json['periode'] as String?,
        jatuhTempo: json['jatuh_tempo'] as String?,
        jenis: json['jenis_tagihan'] is Map<String, dynamic> ? JenisTagihan.fromJson(json['jenis_tagihan'] as Map<String, dynamic>) : null,
        santri: json['santri'] is Map<String, dynamic> ? SantriSingkat.fromJson(json['santri'] as Map<String, dynamic>) : null,
        pembayaran: (json['pembayaran'] as List? ?? []).map((e) => Pembayaran.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

enum StatusPembayaran {
  menunggu('Menunggu'),
  disetujui('Disetujui'),
  ditolak('Ditolak');

  const StatusPembayaran(this.label);
  final String label;

  static StatusPembayaran parse(String? v) => values.firstWhere((s) => s.name == v, orElse: () => menunggu);
}

class Pembayaran {
  const Pembayaran({
    required this.id,
    required this.tagihanId,
    required this.nominal,
    required this.metode,
    required this.sumber,
    required this.status,
    required this.tanggalBayar,
    this.alasanTolak,
    this.catatan,
    this.buktiUrl,
    this.tagihan,
    this.pembuat,
    this.verifikator,
    this.verifiedAt,
    this.createdAt,
  });

  final int id;
  final int tagihanId;
  final int nominal;

  /// 'transfer' / 'tunai'
  final String metode;

  /// 'santri' (upload bukti) / 'bendahara' (input langsung)
  final String sumber;
  final StatusPembayaran status;
  final String tanggalBayar;
  final String? alasanTolak;
  final String? catatan;
  final String? buktiUrl;
  final Tagihan? tagihan;
  final String? pembuat;
  final String? verifikator;
  final String? verifiedAt;
  final String? createdAt;

  String get metodeLabel => metode == 'tunai' ? 'Tunai' : 'Transfer';
  String get sumberLabel => sumber == 'santri' ? 'Upload bukti oleh santri' : 'Dicatat bendahara';

  factory Pembayaran.fromJson(Map<String, dynamic> json) => Pembayaran(
        id: json['id'] as int,
        tagihanId: json['tagihan_id'] as int,
        nominal: _int(json['nominal']),
        metode: json['metode'] as String,
        sumber: json['sumber'] as String,
        status: StatusPembayaran.parse(json['status'] as String?),
        tanggalBayar: json['tanggal_bayar'] as String? ?? '',
        alasanTolak: json['alasan_tolak'] as String?,
        catatan: json['catatan'] as String?,
        buktiUrl: json['bukti_url'] as String?,
        tagihan: json['tagihan'] is Map<String, dynamic> ? Tagihan.fromJson(json['tagihan'] as Map<String, dynamic>) : null,
        pembuat: json['pembuat'] as String?,
        verifikator: json['verifikator'] as String?,
        verifiedAt: json['verified_at'] as String?,
        createdAt: json['created_at'] as String?,
      );
}

class KategoriKas {
  const KategoriKas({required this.id, required this.nama, required this.tipe, required this.sistem});

  final int id;
  final String nama;

  /// 'masuk' / 'keluar'
  final String tipe;

  /// Kategori otomatis (pembayaran santri), tidak bisa diubah
  final bool sistem;

  factory KategoriKas.fromJson(Map<String, dynamic> json) => KategoriKas(
        id: json['id'] as int,
        nama: json['nama'] as String,
        tipe: json['tipe'] as String,
        sistem: json['sistem'] as bool? ?? false,
      );
}

class KasTransaksi {
  const KasTransaksi({
    required this.id,
    required this.gender,
    required this.tipe,
    required this.nominal,
    required this.tanggal,
    required this.keterangan,
    this.kategori,
    this.pembayaranId,
    this.buktiUrl,
    this.pembuat,
  });

  final int id;
  final String gender;
  final String tipe;
  final int nominal;
  final String tanggal;
  final String keterangan;
  final KategoriKas? kategori;
  final int? pembayaranId;
  final String? buktiUrl;
  final String? pembuat;

  bool get masuk => tipe == 'masuk';
  bool get otomatis => pembayaranId != null;

  factory KasTransaksi.fromJson(Map<String, dynamic> json) => KasTransaksi(
        id: json['id'] as int,
        gender: json['gender'] as String,
        tipe: json['tipe'] as String,
        nominal: _int(json['nominal']),
        tanggal: json['tanggal'] as String? ?? '',
        keterangan: json['keterangan'] as String? ?? '',
        kategori: json['kategori'] is Map<String, dynamic> ? KategoriKas.fromJson(json['kategori'] as Map<String, dynamic>) : null,
        pembayaranId: json['pembayaran_id'] as int?,
        buktiUrl: json['bukti_url'] as String?,
        pembuat: json['pembuat'] as String?,
      );
}

/// Saldo kas. Pengurus putra/putri hanya menerima salah satu.
class SaldoKas {
  const SaldoKas({this.putra, this.putri, required this.total});

  final int? putra;
  final int? putri;
  final int total;

  factory SaldoKas.fromJson(Map<String, dynamic> json) => SaldoKas(
        putra: (json['putra'] as num?)?.toInt(),
        putri: (json['putri'] as num?)?.toInt(),
        total: _int(json['total']),
      );
}

/// Ringkasan dari GET /tagihan (seluruh hasil filter, bukan hanya halaman ini).
class RingkasanTagihan {
  const RingkasanTagihan({required this.jumlah, required this.total, required this.terbayar, required this.sisa});

  final int jumlah;
  final int total;
  final int terbayar;
  final int sisa;

  factory RingkasanTagihan.fromJson(Map<String, dynamic>? json) => RingkasanTagihan(
        jumlah: _int(json?['jumlah']),
        total: _int(json?['total']),
        terbayar: _int(json?['terbayar']),
        sisa: _int(json?['sisa']),
      );
}

/// SPP khusus (potongan / bebas SPP) untuk sekelompok santri pada rentang bulan tertentu (nominal 0 = bebas SPP).
class SppKhusus {
  const SppKhusus({
    required this.id,
    required this.nama,
    required this.nominal,
    required this.mulai,
    this.sampai,
    this.keterangan,
    required this.berlaku,
    required this.bisaKelola,
    required this.santri,
  });

  final int id;
  final String nama;
  final int nominal;

  /// Bulan "yyyy-MM"; sampai null = tanpa batas.
  final String mulai;
  final String? sampai;
  final String? keterangan;

  /// Berlaku bulan ini.
  final bool berlaku;

  /// false jika berisi santri di luar wewenang pengguna (hanya admin yang bisa mengubah).
  final bool bisaKelola;
  final List<SantriSingkat> santri;

  bool get bebas => nominal == 0;

  factory SppKhusus.fromJson(Map<String, dynamic> json) => SppKhusus(
        id: json['id'] as int,
        nama: json['nama'] as String,
        nominal: _int(json['nominal']),
        mulai: json['mulai'] as String,
        sampai: json['sampai'] as String?,
        keterangan: json['keterangan'] as String?,
        berlaku: json['berlaku'] as bool? ?? false,
        bisaKelola: json['bisa_kelola'] as bool? ?? true,
        santri: [for (final e in json['santri'] as List? ?? const []) SantriSingkat.fromJson(e as Map<String, dynamic>)],
      );
}
