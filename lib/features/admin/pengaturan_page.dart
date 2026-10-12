import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../shared/ui.dart';
import '../../shared/widgets.dart';
import 'admin_repository.dart';

/// Pengaturan pondok (khusus admin). Nama, alamat, dan logo tampil di kartu santri
/// dan halaman verifikasi QR.
class PengaturanPage extends ConsumerStatefulWidget {
  const PengaturanPage({super.key});

  @override
  ConsumerState<PengaturanPage> createState() => _PengaturanPageState();
}

class _PengaturanPageState extends ConsumerState<PengaturanPage> {
  final _form = GlobalKey<FormState>();
  final _nama = TextEditingController();
  final _alamat = TextEditingController();
  final _telepon = TextEditingController();
  final _website = TextEditingController();
  final _jatuhTempo = TextEditingController();
  String? _logoUrl;
  UploadFile? _logoBaru;
  bool _siap = false;
  bool _loading = false;
  String? _error;
  Map<String, List<String>> _errors = const {};

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    for (final c in [_nama, _alamat, _telepon, _website, _jatuhTempo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() => _error = null);
    try {
      _isi(await ref.read(adminRepositoryProvider).pengaturan());
      setState(() => _siap = true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  void _isi(Map<String, dynamic> d) {
    _nama.text = '${d['nama_pondok'] ?? ''}';
    _alamat.text = '${d['alamat_pondok'] ?? ''}';
    _telepon.text = '${d['telepon_pondok'] ?? ''}';
    _website.text = '${d['website_pondok'] ?? ''}';
    _jatuhTempo.text = '${d['spp_jatuh_tempo_hari'] ?? 10}';
    // Tambah penanda waktu supaya logo baru langsung tampil (tidak memakai cache)
    _logoUrl = d['logo_url'] == null ? null : '${d['logo_url']}?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _pilihLogo() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 90);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (bytes.length > 1024 * 1024) {
      if (mounted) showPesan(context, 'Ukuran logo maksimal 1 MB.', error: true);
      return;
    }
    setState(() => _logoBaru = UploadFile(x.name, bytes));
  }

  Future<void> _simpan() async {
    setState(() => _errors = const {});
    if (!_form.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final hasil = await ref.read(adminRepositoryProvider).simpanPengaturan({
        'nama_pondok': _nama.text.trim(),
        'alamat_pondok': _alamat.text.trim(),
        'telepon_pondok': _telepon.text.trim(),
        'website_pondok': _website.text.trim(),
        'spp_jatuh_tempo_hari': _jatuhTempo.text.trim(),
      }, logo: _logoBaru);
      if (!mounted) return;
      setState(() {
        _isi(hasil);
        _logoBaru = null;
      });
      showPesan(context, 'Pengaturan disimpan.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errors = e.errors);
      _form.currentState!.validate();
      showPesan(context, e.errors.values.firstOrNull?.first ?? e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Pondok')),
      body: _error != null
          ? ErrorView(message: _error!, onRetry: _muat)
          : !_siap
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _form,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    children: [
                      Center(
                        child: InkWell(
                          onTap: _pilihLogo,
                          customBorder: const CircleBorder(),
                          child: Column(
                            children: [
                              Container(
                                width: 104,
                                height: 104,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.emas, width: 3),
                                ),
                                child: _logoBaru != null
                                    ? Image.memory(_logoBaru!.bytes)
                                    : _logoUrl != null
                                        ? Image.network(_logoUrl!, errorBuilder: (_, _, _) => Image.asset('assets/images/logo.png'))
                                        : Image.asset('assets/images/logo.png'),
                              ),
                              const SizedBox(height: 8),
                              Text('Ganti logo', style: text.labelLarge?.copyWith(color: AppColors.hijau, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const JudulForm('Identitas pondok', icon: Icons.apartment_rounded),
                      TextFormField(
                        controller: _nama,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Nama pondok'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama pondok wajib diisi.' : _errors['nama_pondok']?.first,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _alamat,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Alamat singkat', helperText: 'Tampil di kartu santri, contoh: Tambakberas Barat, Jombang'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _telepon,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Telepon (opsional)'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _website,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(labelText: 'Website', hintText: 'https://as-salafiyah.id'),
                        validator: (_) => _errors['website_pondok']?.first,
                      ),
                      const JudulForm('Tagihan SPP', icon: Icons.event_repeat_rounded),
                      TextFormField(
                        controller: _jatuhTempo,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: 'Tanggal jatuh tempo SPP setiap bulan',
                          helperText: 'Antara 1 – 28. Nominal SPP diatur di menu Keuangan → Jenis tagihan.',
                          helperMaxLines: 2,
                        ),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n < 1 || n > 28) return 'Isi tanggal 1 sampai 28.';
                          return _errors['spp_jatuh_tempo_hari']?.first;
                        },
                      ),
                      const SizedBox(height: 24),
                      TombolSimpan(loading: _loading, onPressed: _simpan, label: 'Simpan pengaturan'),
                    ],
                  ),
                ),
    );
  }
}
