class Komplek {
  const Komplek({
    required this.id,
    required this.nama,
    required this.gender,
    required this.genderLabel,
    this.keterangan,
    this.jumlahKamar = 0,
    this.totalKapasitas = 0,
    this.kamar = const [],
  });

  final int id;
  final String nama;
  final String gender;
  final String genderLabel;
  final String? keterangan;
  final int jumlahKamar;
  final int totalKapasitas;
  final List<Kamar> kamar;

  factory Komplek.fromJson(Map<String, dynamic> json) => Komplek(
        id: json['id'] as int,
        nama: json['nama'] as String,
        gender: json['gender'] as String,
        genderLabel: json['gender_label'] as String? ?? (json['gender'] == 'P' ? 'Putri' : 'Putra'),
        keterangan: json['keterangan'] as String?,
        jumlahKamar: (json['jumlah_kamar'] as num?)?.toInt() ?? 0,
        totalKapasitas: (json['total_kapasitas'] as num?)?.toInt() ?? 0,
        kamar: (json['kamar'] as List? ?? []).map((k) => Kamar.fromJson(k as Map<String, dynamic>)).toList(),
      );
}

class Kamar {
  const Kamar({
    required this.id,
    required this.komplekId,
    required this.nama,
    required this.kapasitas,
    this.terisi,
    this.komplek,
  });

  final int id;
  final int komplekId;
  final String nama;
  final int kapasitas;

  /// Jumlah santri aktif (null jika server tidak mengirim)
  final int? terisi;
  final Komplek? komplek;

  int get sisa => kapasitas - (terisi ?? 0);
  bool get penuh => terisi != null && terisi! >= kapasitas;

  /// "Kamar 3 · Komplek Al-Ikhlas"
  String get labelLengkap => komplek == null ? nama : '$nama · ${komplek!.nama}';

  factory Kamar.fromJson(Map<String, dynamic> json) => Kamar(
        id: json['id'] as int,
        komplekId: json['komplek_id'] as int,
        nama: json['nama'] as String,
        kapasitas: (json['kapasitas'] as num).toInt(),
        terisi: (json['terisi'] as num?)?.toInt(),
        komplek: json['komplek'] is Map<String, dynamic> ? Komplek.fromJson(json['komplek'] as Map<String, dynamic>) : null,
      );
}
