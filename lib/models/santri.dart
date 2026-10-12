import 'komplek.dart';

enum StatusSantri {
  aktif('Aktif'),
  lulus('Lulus'),
  keluar('Keluar');

  const StatusSantri(this.label);
  final String label;

  static StatusSantri parse(String? v) => StatusSantri.values.firstWhere((s) => s.name == v, orElse: () => StatusSantri.aktif);
}

/// Jenis dokumen santri yang bisa diunggah.
enum JenisDokumen {
  fotoProfil('foto_profil', 'Foto profil'),
  kk('file_kk', 'Kartu Keluarga'),
  akta('file_akta', 'Akta Kelahiran'),
  ktp('file_ktp', 'KTP');

  const JenisDokumen(this.key, this.label);
  final String key;
  final String label;
}

/// Data santri. Field sensitif (NIK, alamat, orang tua, dokumen) hanya terisi
/// untuk admin, sekretaris, dan santri itu sendiri.
class Santri {
  const Santri({
    required this.id,
    required this.nis,
    required this.namaLengkap,
    required this.jenisKelamin,
    required this.jenisKelaminLabel,
    required this.tempatLahir,
    required this.tanggalLahir,
    required this.status,
    required this.tanggalMasuk,
    this.tanggalKeluar,
    this.kamar,
    this.fotoUrl,
    this.isActive,
    this.lengkap = false,
    this.raw = const {},
    this.dokumen = const {},
  });

  final int id;
  final String nis;
  final String namaLengkap;
  final String jenisKelamin;
  final String jenisKelaminLabel;
  final String tempatLahir;
  final String tanggalLahir;
  final StatusSantri status;
  final String tanggalMasuk;
  final String? tanggalKeluar;
  final Kamar? kamar;
  final String? fotoUrl;

  /// Status akun login (null jika server tidak mengirim)
  final bool? isActive;

  /// true jika data sensitif ikut dikirim server
  final bool lengkap;

  /// Data asli dari server, dipakai untuk mengisi form ubah
  final Map<String, dynamic> raw;

  /// URL unduh dokumen per jenis (null = belum diunggah)
  final Map<String, String?> dokumen;

  bool get putri => jenisKelamin == 'P';

  String? field(String key) {
    final v = raw[key];
    return v == null ? null : '$v';
  }

  String get inisial {
    final parts = namaLengkap.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts[1][0] : '')).toUpperCase();
  }

  factory Santri.fromJson(Map<String, dynamic> json) {
    final dok = json['dokumen'] as Map<String, dynamic>?;
    return Santri(
      id: json['id'] as int,
      nis: json['nis'] as String,
      namaLengkap: json['nama_lengkap'] as String,
      jenisKelamin: json['jenis_kelamin'] as String,
      jenisKelaminLabel: json['jenis_kelamin_label'] as String? ?? '',
      tempatLahir: json['tempat_lahir'] as String? ?? '',
      tanggalLahir: json['tanggal_lahir'] as String? ?? '',
      status: StatusSantri.parse(json['status'] as String?),
      tanggalMasuk: json['tanggal_masuk'] as String? ?? '',
      tanggalKeluar: json['tanggal_keluar'] as String?,
      kamar: json['kamar'] is Map<String, dynamic> ? Kamar.fromJson(json['kamar'] as Map<String, dynamic>) : null,
      fotoUrl: json['foto_url'] as String?,
      isActive: json['is_active'] as bool?,
      lengkap: json.containsKey('nik'),
      raw: json,
      dokumen: dok == null ? const {} : dok.map((k, v) => MapEntry(k, v as String?)),
    );
  }
}

/// Satu halaman hasil dari endpoint berpaginasi Laravel.
class Halaman<T> {
  const Halaman({required this.items, required this.page, required this.lastPage, required this.total});

  final List<T> items;
  final int page;
  final int lastPage;
  final int total;

  bool get adaLagi => page < lastPage;

  factory Halaman.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) parse) {
    // API Resource menaruh info halaman di "meta"; paginator biasa di level atas
    final meta = json['meta'] as Map<String, dynamic>? ?? json;
    return Halaman(
      items: (json['data'] as List).map((e) => parse(e as Map<String, dynamic>)).toList(),
      page: (meta['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (meta['last_page'] as num?)?.toInt() ?? 1,
      total: (meta['total'] as num?)?.toInt() ?? 0,
    );
  }
}
