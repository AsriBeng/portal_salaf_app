enum Role {
  admin('Admin / Pengasuh'),
  ketua('Ketua'),
  sekretaris('Sekretaris'),
  bendahara('Bendahara'),
  santri('Santri');

  const Role(this.label);
  final String label;

  static Role parse(String? value) => Role.values.firstWhere((r) => r.name == value, orElse: () => Role.santri);
}

class SantriRingkas {
  const SantriRingkas({
    required this.id,
    required this.nis,
    required this.namaLengkap,
    required this.jenisKelamin,
    required this.status,
    this.fotoUrl,
    this.kamar,
    this.komplek,
  });

  final int id;
  final String nis;
  final String namaLengkap;
  final String jenisKelamin;
  final String status;
  final String? fotoUrl;
  final String? kamar;
  final String? komplek;

  factory SantriRingkas.fromJson(Map<String, dynamic> json) {
    final kamar = json['kamar'] as Map<String, dynamic>?;
    return SantriRingkas(
      id: json['id'] as int,
      nis: json['nis'] as String,
      namaLengkap: json['nama_lengkap'] as String,
      jenisKelamin: json['jenis_kelamin'] as String,
      status: json['status'] as String,
      fotoUrl: json['foto_url'] as String?,
      kamar: kamar?['nama'] as String?,
      komplek: (kamar?['komplek'] as Map<String, dynamic>?)?['nama'] as String?,
    );
  }
}

class User {
  const User({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    this.gender,
    this.genderLabel,
    this.phone,
    this.fotoUrl,
    this.santri,
  });

  final int id;
  final String name;
  final String username;
  final Role role;

  /// 'L' / 'P'; null untuk admin (melihat putra dan putri)
  final String? gender;
  final String? genderLabel;
  final String? phone;

  /// Foto profil pengurus (null untuk santri; santri memakai foto di data santri)
  final String? fotoUrl;
  final SantriRingkas? santri;

  bool get isSantri => role == Role.santri;
  bool get isAdmin => role == Role.admin;

  /// Foto yang ditampilkan: santri memakai foto kartunya, pengurus memakai foto profilnya.
  String? get fotoProfil => santri?.fotoUrl ?? fotoUrl;

  /// "Sekretaris Putra", "Admin / Pengasuh", "Santri Putri"
  String get jabatan => gender == null || isAdmin ? role.label : '${role.label} $genderLabel';

  String get inisial {
    // Hanya kata yang diawali huruf, supaya "Admin / Pengasuh" menjadi "AP"
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => RegExp(r'^[A-Za-z]').hasMatch(p)).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts[1][0] : '')).toUpperCase();
  }

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        name: json['name'] as String,
        username: json['username'] as String,
        role: Role.parse(json['role'] as String?),
        gender: json['gender'] as String?,
        genderLabel: json['gender_label'] as String?,
        phone: json['phone'] as String?,
        fotoUrl: json['foto_url'] as String?,
        santri: json['santri'] is Map<String, dynamic> ? SantriRingkas.fromJson(json['santri'] as Map<String, dynamic>) : null,
      );
}
