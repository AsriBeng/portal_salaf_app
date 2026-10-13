class Pengumuman {
  const Pengumuman({
    required this.id,
    required this.judul,
    required this.isi,
    required this.target,
    required this.publishedAt,
    this.lampiranUrl,
    this.pembuatId,
    this.pembuatNama,
    this.pembuatPeran,
    this.pembuatFotoUrl,
  });

  final int id;
  final String judul;
  final String isi;

  /// 'semua' / 'putra' / 'putri'
  final String target;
  final String publishedAt;
  final String? lampiranUrl;
  final int? pembuatId;
  final String? pembuatNama;
  final String? pembuatPeran;
  final String? pembuatFotoUrl;

  String get targetLabel => switch (target) {
        'putra' => 'Santri putra',
        'putri' => 'Santri putri',
        _ => 'Semua',
      };

  factory Pengumuman.fromJson(Map<String, dynamic> json) {
    final pembuat = json['pembuat'] as Map<String, dynamic>?;
    return Pengumuman(
      id: json['id'] as int,
      judul: json['judul'] as String,
      isi: json['isi'] as String,
      target: json['target'] as String,
      publishedAt: json['published_at'] as String? ?? '',
      lampiranUrl: json['lampiran_url'] as String?,
      pembuatId: pembuat?['id'] as int?,
      pembuatNama: pembuat?['name'] as String?,
      pembuatPeran: pembuat?['role'] as String?,
      pembuatFotoUrl: pembuat?['foto_url'] as String?,
    );
  }
}

class Notifikasi {
  const Notifikasi({
    required this.id,
    required this.tipe,
    required this.judul,
    required this.isi,
    required this.dibaca,
    required this.createdAt,
    this.refId,
  });

  final String id;

  /// 'pengumuman' / 'tagihan' / 'pembayaran'
  final String tipe;
  final int? refId;
  final String judul;
  final String isi;
  final bool dibaca;
  final String createdAt;

  /// Halaman yang dibuka saat notifikasi diketuk.
  String? get tujuan => refId == null
      ? null
      : switch (tipe) {
          'pengumuman' => '/pengumuman/$refId',
          'tagihan' => '/tagihan/$refId',
          'pembayaran' => '/pembayaran/$refId',
          _ => null,
        };

  Notifikasi tandaiDibaca() =>
      Notifikasi(id: id, tipe: tipe, refId: refId, judul: judul, isi: isi, dibaca: true, createdAt: createdAt);

  factory Notifikasi.fromJson(Map<String, dynamic> json) => Notifikasi(
        id: json['id'] as String,
        tipe: json['tipe'] as String? ?? '',
        refId: int.tryParse('${json['ref_id'] ?? ''}'),
        judul: json['judul'] as String? ?? '',
        isi: json['isi'] as String? ?? '',
        dibaca: json['dibaca'] as bool? ?? false,
        createdAt: json['created_at'] as String? ?? '',
      );
}
