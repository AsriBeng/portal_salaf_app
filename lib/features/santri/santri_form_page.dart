import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/komplek.dart';
import '../../models/santri.dart';
import '../../shared/ui.dart';
import '../auth/auth_controller.dart';
import '../komplek/komplek_forms.dart';
import '../komplek/komplek_repository.dart';
import 'santri_repository.dart';

/// Form tambah santri (santri == null) atau ubah data santri.
class SantriFormPage extends ConsumerStatefulWidget {
  const SantriFormPage({super.key, this.santriId});

  final int? santriId;

  @override
  ConsumerState<SantriFormPage> createState() => _SantriFormPageState();
}

class _SantriFormPageState extends ConsumerState<SantriFormPage> {
  final _form = GlobalKey<FormState>();
  final _c = <String, TextEditingController>{};
  Map<String, List<String>> _errors = const {};

  Santri? _santri;
  bool _siap = false;
  bool _loading = false;

  String? _gender;
  int? _kamarId;
  StatusSantri _status = StatusSantri.aktif;
  DateTime? _tanggalLahir;
  DateTime _tanggalMasuk = DateTime.now();
  DateTime? _tanggalKeluar;
  UploadFile? _foto;

  bool get _baru => widget.santriId == null;

  static const _teks = [
    'nis', 'password', 'nama_lengkap', 'nik', 'no_kk', 'tempat_lahir', 'agama', 'kewarganegaraan',
    'anak_ke', 'jumlah_saudara', 'no_telepon', 'alamat', 'rt', 'rw', 'kelurahan', 'kecamatan',
    'kabupaten', 'provinsi', 'kode_pos', 'nama_ayah', 'pekerjaan_ayah', 'no_telepon_ayah',
    'nama_ibu', 'pekerjaan_ibu', 'no_telepon_ibu', 'nama_wali', 'hubungan_wali', 'no_telepon_wali',
  ];

  TextEditingController c(String key) => _c.putIfAbsent(key, TextEditingController.new);

  @override
  void initState() {
    super.initState();
    c('agama').text = 'Islam';
    c('kewarganegaraan').text = 'WNI';
    _isiAwal();
  }

  Future<void> _isiAwal() async {
    final user = ref.read(authControllerProvider).value!;
    if (!user.isAdmin) _gender = user.gender;

    if (_baru) {
      setState(() => _siap = true);
      return;
    }

    try {
      final s = await ref.read(santriRepositoryProvider).detail(widget.santriId!);
      for (final key in _teks) {
        if (key != 'password') c(key).text = s.field(key) ?? '';
      }
      setState(() {
        _santri = s;
        _gender = s.jenisKelamin;
        _kamarId = s.kamar?.id;
        _status = s.status;
        _tanggalLahir = DateTime.tryParse(s.tanggalLahir);
        _tanggalMasuk = DateTime.tryParse(s.tanggalMasuk) ?? DateTime.now();
        _tanggalKeluar = s.tanggalKeluar == null ? null : DateTime.tryParse(s.tanggalKeluar!);
        _siap = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      showPesan(context, e.message, error: true);
      context.kembali();
    }
  }

  @override
  void dispose() {
    for (final ctrl in _c.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  String? _wajib(String key, String label, String? v) =>
      (v == null || v.trim().isEmpty) ? '$label wajib diisi.' : _errors[key]?.first;

  String? _server(String key) => _errors[key]?.first;

  String _iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _pilihFoto() async {
    final sumber = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Ambil dari kamera'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Pilih dari galeri'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (sumber == null) return;

    final file = await ImagePicker().pickImage(source: sumber, maxWidth: 900, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _foto = UploadFile(file.name, bytes));
  }

  Future<void> _simpan() async {
    setState(() => _errors = const {});
    final valid = _form.currentState!.validate();

    if (_gender == null) {
      showPesan(context, 'Pilih jenis kelamin santri.', error: true);
      return;
    }
    if (_tanggalLahir == null) {
      showPesan(context, 'Tanggal lahir wajib diisi.', error: true);
      return;
    }
    if (!valid) {
      showPesan(context, 'Periksa kembali isian yang ditandai merah.', error: true);
      return;
    }

    final data = <String, dynamic>{
      for (final key in _teks)
        if (key != 'password' || _baru) key: c(key).text.trim(),
      'tanggal_lahir': _iso(_tanggalLahir!),
      'tanggal_masuk': _iso(_tanggalMasuk),
      'kamar_id': _kamarId,
      if (_baru) 'jenis_kelamin': _gender,
      if (!_baru) 'status': _status.name,
      if (!_baru && _status != StatusSantri.aktif) 'tanggal_keluar': _tanggalKeluar == null ? null : _iso(_tanggalKeluar!),
    };

    setState(() => _loading = true);
    final repo = ref.read(santriRepositoryProvider);
    try {
      var santri = await repo.simpan(id: widget.santriId, data: data);
      if (_foto != null) santri = await repo.uploadDokumen(santri.id, JenisDokumen.fotoProfil, _foto!);

      ref.invalidate(santriDetailProvider(santri.id));
      ref.invalidate(kamarPilihanProvider);
      ref.invalidate(komplekDetailProvider);
      if (!mounted) return;

      if (_baru) {
        final pass = c('password').text.isEmpty
            ? 'Password awal: tanggal lahir (format ddmmyyyy).'
            : 'Password sesuai yang diisi.';
        showPesan(context, 'Santri ditambahkan. Login dengan NIS ${santri.nis}. $pass');
        context.pushReplacement('/santri/${santri.id}');
      } else {
        showPesan(context, 'Data santri disimpan.');
        context.kembali(true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errors = e.errors);
      _form.currentState!.validate();
      showPesan(context, e.errors.isEmpty ? e.message : (e.errors.values.first.first), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: Text(_baru ? 'Tambah Santri' : 'Ubah Data Santri')),
      body: !_siap
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  _FotoPilih(
                    foto: _foto,
                    fotoUrl: _santri?.fotoUrl,
                    inisial: _santri?.inisial ?? '+',
                    headers: ref.read(apiClientProvider).authHeaders,
                    onTap: _pilihFoto,
                  ),
                  const SizedBox(height: 8),

                  // Akun
                  const JudulForm('Akun', icon: Icons.badge_outlined),
                  _field('nis', 'NIS', wajib: true, icon: Icons.badge_outlined, keyboard: TextInputType.text,
                      helper: 'Dipakai santri untuk login.'),
                  if (_baru)
                    _field('password', 'Password awal (opsional)', icon: Icons.lock_outline_rounded,
                        helper: 'Kosongkan untuk memakai tanggal lahir (ddmmyyyy).',
                        validator: (v) => (v != null && v.isNotEmpty && v.length < 6) ? 'Minimal 6 karakter.' : _server('password')),

                  // Identitas
                  const JudulForm('Identitas', icon: Icons.person_outline_rounded),
                  _field('nama_lengkap', 'Nama lengkap', wajib: true, caps: TextCapitalization.words),
                  if (_baru && user.isAdmin) ...[
                    Text('Jenis kelamin', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    PilihGender(
                      value: _gender,
                      onChanged: (g) => setState(() {
                        _gender = g;
                        _kamarId = null;
                      }),
                    ),
                    const SizedBox(height: 14),
                  ] else
                    _InfoTetap(label: 'Jenis kelamin', value: _gender == 'P' ? 'Perempuan (putri)' : 'Laki-laki (putra)'),
                  _field('nik', 'NIK (opsional)', angka: true, maxLength: 16,
                      validator: (v) => (v != null && v.isNotEmpty && v.length != 16) ? 'NIK harus 16 angka.' : _server('nik')),
                  _field('no_kk', 'Nomor KK (opsional)', angka: true, maxLength: 16,
                      validator: (v) => (v != null && v.isNotEmpty && v.length != 16) ? 'Nomor KK harus 16 angka.' : _server('no_kk')),
                  _field('tempat_lahir', 'Tempat lahir', wajib: true, caps: TextCapitalization.words),
                  _Tanggal(
                    label: 'Tanggal lahir',
                    value: _tanggalLahir,
                    error: _server('tanggal_lahir'),
                    awal: DateTime(DateTime.now().year - 12),
                    onChanged: (d) => setState(() => _tanggalLahir = d),
                  ),
                  Row(children: [
                    Expanded(child: _field('agama', 'Agama', wajib: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _field('kewarganegaraan', 'Kewarganegaraan', wajib: true)),
                  ]),
                  Row(children: [
                    Expanded(child: _field('anak_ke', 'Anak ke-', angka: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _field('jumlah_saudara', 'Jumlah saudara', angka: true)),
                  ]),
                  _field('no_telepon', 'No. telepon santri (opsional)', keyboard: TextInputType.phone),

                  // Alamat
                  const JudulForm('Alamat asal (sesuai KK)', icon: Icons.home_outlined),
                  _field('alamat', 'Alamat / jalan / dusun', wajib: true, maxLines: 2),
                  Row(children: [
                    Expanded(child: _field('rt', 'RT', angka: true, maxLength: 3)),
                    const SizedBox(width: 12),
                    Expanded(child: _field('rw', 'RW', angka: true, maxLength: 3)),
                    const SizedBox(width: 12),
                    Expanded(child: _field('kode_pos', 'Kode pos', angka: true, maxLength: 5)),
                  ]),
                  _field('kelurahan', 'Desa / kelurahan', wajib: true, caps: TextCapitalization.words),
                  _field('kecamatan', 'Kecamatan', wajib: true, caps: TextCapitalization.words),
                  _field('kabupaten', 'Kabupaten / kota', wajib: true, caps: TextCapitalization.words),
                  _field('provinsi', 'Provinsi', wajib: true, caps: TextCapitalization.words),

                  // Orang tua
                  const JudulForm('Orang tua', icon: Icons.family_restroom_rounded),
                  _field('nama_ayah', 'Nama ayah', wajib: true, caps: TextCapitalization.words),
                  _field('pekerjaan_ayah', 'Pekerjaan ayah'),
                  _field('no_telepon_ayah', 'No. telepon ayah', keyboard: TextInputType.phone),
                  _field('nama_ibu', 'Nama ibu', wajib: true, caps: TextCapitalization.words),
                  _field('pekerjaan_ibu', 'Pekerjaan ibu'),
                  _field('no_telepon_ibu', 'No. telepon ibu', keyboard: TextInputType.phone),

                  // Wali
                  const JudulForm('Wali (jika bukan orang tua)', icon: Icons.supervisor_account_outlined),
                  _field('nama_wali', 'Nama wali', caps: TextCapitalization.words),
                  _field('hubungan_wali', 'Hubungan dengan santri', helper: 'contoh: paman, kakek'),
                  _field('no_telepon_wali', 'No. telepon wali', keyboard: TextInputType.phone),

                  // Pondok
                  const JudulForm('Data pondok', icon: Icons.apartment_rounded),
                  _Tanggal(
                    label: 'Tanggal masuk',
                    value: _tanggalMasuk,
                    error: _server('tanggal_masuk'),
                    onChanged: (d) => setState(() => _tanggalMasuk = d ?? _tanggalMasuk),
                  ),
                  _PilihKamar(
                    gender: _gender,
                    value: _kamarId,
                    kamarSekarang: _santri?.kamar?.id,
                    error: _server('kamar_id'),
                    onChanged: (id) => setState(() => _kamarId = id),
                  ),
                  if (!_baru) ...[
                    DropdownButtonFormField<StatusSantri>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status santri', prefixIcon: Icon(Icons.flag_outlined)),
                      items: [for (final s in StatusSantri.values) DropdownMenuItem(value: s, child: Text(s.label))],
                      onChanged: (s) => setState(() => _status = s ?? _status),
                    ),
                    const SizedBox(height: 14),
                    if (_status != StatusSantri.aktif)
                      _Tanggal(
                        label: 'Tanggal keluar',
                        value: _tanggalKeluar,
                        error: _server('tanggal_keluar'),
                        onChanged: (d) => setState(() => _tanggalKeluar = d),
                      ),
                    if (_status != StatusSantri.aktif)
                      const _Catatan('Kartu santri otomatis tidak berlaku jika status bukan Aktif.'),
                  ],
                  const SizedBox(height: 12),
                  TombolSimpan(loading: _loading, onPressed: _simpan, label: _baru ? 'Simpan santri' : 'Simpan perubahan'),
                ],
              ),
            ),
    );
  }

  Widget _field(
    String key,
    String label, {
    bool wajib = false,
    bool angka = false,
    int? maxLength,
    int maxLines = 1,
    IconData? icon,
    String? helper,
    TextInputType? keyboard,
    TextCapitalization caps = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c(key),
        keyboardType: angka ? TextInputType.number : keyboard,
        inputFormatters: [
          if (angka) FilteringTextInputFormatter.digitsOnly,
          if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
        ],
        maxLines: maxLines,
        textCapitalization: caps,
        textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
        decoration: InputDecoration(
          labelText: wajib ? '$label *' : label,
          helperText: helper,
          prefixIcon: icon == null ? null : Icon(icon),
        ),
        validator: validator ?? (v) => wajib ? _wajib(key, label, v) : _server(key),
      ),
    );
  }
}

class _FotoPilih extends StatelessWidget {
  const _FotoPilih({
    required this.foto,
    required this.fotoUrl,
    required this.inisial,
    required this.headers,
    required this.onTap,
  });

  final UploadFile? foto;
  final String? fotoUrl;
  final String inisial;
  final Map<String, String> headers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Widget gambar = foto != null
        ? Image.memory(foto!.bytes, fit: BoxFit.cover)
        : fotoUrl != null
            ? Image.network(fotoUrl!, headers: headers, fit: BoxFit.cover)
            : const Icon(Icons.add_a_photo_outlined, color: AppColors.hijau, size: 32);

    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              width: 96,
              height: 128,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.hijauMuda,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.garis),
              ),
              child: Center(child: gambar),
            ),
            const SizedBox(height: 8),
            Text(
              foto != null || fotoUrl != null ? 'Ganti foto' : 'Tambah foto (3x4)',
              style: const TextStyle(color: AppColors.hijau, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTetap extends StatelessWidget {
  const _InfoTetap({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.wc_rounded), enabled: false),
        child: Text(value),
      ),
    );
  }
}

class _Catatan extends StatelessWidget {
  const _Catatan(this.isi);

  final String isi;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.oranyeMuda, borderRadius: BorderRadius.circular(12)),
      child: Text(isi, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.oranye)),
    );
  }
}

/// Field tanggal dengan kalender.
class _Tanggal extends StatelessWidget {
  const _Tanggal({required this.label, required this.value, required this.onChanged, this.error, this.awal});

  final String label;
  final DateTime? value;
  final String? error;
  final DateTime? awal;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: value ?? awal ?? DateTime.now(),
            firstDate: DateTime(1950),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            helpText: label,
          );
          if (d != null) onChanged(d);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: '$label *',
            errorText: error,
            prefixIcon: const Icon(Icons.calendar_today_outlined),
          ),
          child: Text(
            value == null ? 'Pilih tanggal' : DateFormat('d MMMM yyyy', 'id_ID').format(value!),
            style: TextStyle(color: value == null ? AppColors.teks2 : AppColors.teks),
          ),
        ),
      ),
    );
  }
}

/// Dropdown kamar sesuai jenis kelamin santri; kamar penuh tidak bisa dipilih.
class _PilihKamar extends ConsumerWidget {
  const _PilihKamar({
    required this.gender,
    required this.value,
    required this.kamarSekarang,
    required this.onChanged,
    this.error,
  });

  final String? gender;
  final int? value;
  final int? kamarSekarang;
  final String? error;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (gender == null) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 14),
        child: InputDecorator(
          decoration: InputDecoration(labelText: 'Kamar', prefixIcon: Icon(Icons.meeting_room_outlined), enabled: false),
          child: Text('Pilih jenis kelamin terlebih dahulu'),
        ),
      );
    }

    final daftar = ref.watch(kamarPilihanProvider(gender));

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: daftar.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text('Gagal memuat kamar: $e', style: const TextStyle(color: AppColors.merah)),
        data: (kamar) {
          bool bisaDipilih(Kamar k) => !k.penuh || k.id == kamarSekarang;

          return DropdownButtonFormField<int?>(
            key: ValueKey('kamar-$gender'),
            initialValue: kamar.any((k) => k.id == value) ? value : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Kamar',
              errorText: error,
              helperText: kamar.isEmpty ? 'Belum ada kamar. Tambahkan dulu di menu Kamar.' : null,
              prefixIcon: const Icon(Icons.meeting_room_outlined),
            ),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Belum ditempatkan')),
              for (final k in kamar)
                DropdownMenuItem<int?>(
                  value: k.id,
                  enabled: bisaDipilih(k),
                  child: Text(
                    '${k.labelLengkap}  (${k.penuh ? 'penuh' : 'sisa ${k.sisa}'})',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: bisaDipilih(k) ? AppColors.teks : AppColors.teks2),
                  ),
                ),
            ],
            onChanged: onChanged,
          );
        },
      ),
    );
  }
}
