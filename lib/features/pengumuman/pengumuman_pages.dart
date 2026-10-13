import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/akses.dart';
import '../../models/pengumuman.dart';
import '../../models/user.dart';
import '../../shared/lampiran.dart';
import '../../shared/paged_list.dart';
import '../../shared/ui.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';
import '../home/dashboard_provider.dart';
import 'pengumuman_repository.dart';

/// Lencana sasaran pengumuman.
class TargetPill extends StatelessWidget {
  const TargetPill(this.target, {super.key});

  final String target;

  @override
  Widget build(BuildContext context) => switch (target) {
        'putra' => const Pill(label: 'Putra', color: AppColors.biru, background: AppColors.biruMuda),
        'putri' => const Pill(label: 'Putri', color: Color(0xFFBE185D), background: Color(0xFFFCE7F3)),
        _ => const Pill(label: 'Semua', color: Color(0xFF8A6D00), background: AppColors.emasMuda),
      };
}

/// Foto, nama, dan jabatan pembuat pengumuman.
class PembuatPengumuman extends ConsumerWidget {
  const PembuatPengumuman({super.key, required this.pengumuman, this.ukuran = 28});

  final Pengumuman pengumuman;
  final double ukuran;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final nama = pengumuman.pembuatNama ?? '';
    final inisial = nama
        .split(RegExp(r'\s+'))
        .where((k) => RegExp(r'^[A-Za-z]').hasMatch(k))
        .take(2)
        .map((k) => k[0].toUpperCase())
        .join();

    return Row(
      children: [
        UserAvatar(
          inisial: inisial.isEmpty ? '?' : inisial,
          fotoUrl: pengumuman.pembuatFotoUrl,
          headers: ref.read(apiClientProvider).authHeaders,
          size: ukuran,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: nama, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.teks)),
              if (pengumuman.pembuatPeran != null) TextSpan(text: ' · ${pengumuman.pembuatPeran}'),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(color: AppColors.teks2),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Daftar pengumuman
// ---------------------------------------------------------------------------

class PengumumanListPage extends ConsumerStatefulWidget {
  const PengumumanListPage({super.key});

  @override
  ConsumerState<PengumumanListPage> createState() => _PengumumanListPageState();
}

class _PengumumanListPageState extends ConsumerState<PengumumanListPage> {
  final _cari = TextEditingController();
  Timer? _jeda;
  String _kata = '';
  int _versi = 0;

  @override
  void dispose() {
    _jeda?.cancel();
    _cari.dispose();
    super.dispose();
  }

  Future<void> _buka(String path) async {
    final berubah = await context.push<bool>(path);
    if (!mounted) return;
    setState(() => _versi++);
    if (berubah == true) ref.invalidate(dashboardProvider);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const SizedBox.shrink();
    final repo = ref.read(pengumumanRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengumuman')),
      floatingActionButton: user.bisaBuatPengumuman
          ? FloatingActionButton.extended(
              onPressed: () => _buka('/pengumuman-baru'),
              icon: const Icon(Icons.campaign_rounded),
              label: const Text('Buat'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _cari,
              decoration: const InputDecoration(hintText: 'Cari judul pengumuman', prefixIcon: Icon(Icons.search_rounded)),
              onChanged: (v) {
                _jeda?.cancel();
                _jeda = Timer(const Duration(milliseconds: 450), () => setState(() => _kata = v.trim()));
              },
            ),
          ),
          Expanded(
            child: PagedList<Pengumuman>(
              reloadKey: '$_kata|$_versi',
              muat: (page) => repo.daftar(page: page, search: _kata),
              itemBuilder: (_, p) => PengumumanCard(pengumuman: p, onTap: () => _buka('/pengumuman/${p.id}')),
              kosong: EmptyView(
                icon: Icons.campaign_outlined,
                judul: _kata.isEmpty ? 'Belum ada pengumuman' : 'Pengumuman tidak ditemukan',
                isi: user.bisaBuatPengumuman && _kata.isEmpty ? 'Ketuk tombol Buat untuk mengirim pengumuman pertama.' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PengumumanCard extends StatelessWidget {
  const PengumumanCard({super.key, required this.pengumuman, required this.onTap});

  final Pengumuman pengumuman;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = pengumuman;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TargetPill(p.target),
                  if (p.lampiranUrl != null) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.attach_file_rounded, size: 16, color: AppColors.teks2),
                  ],
                  const Spacer(),
                  Text(tanggal(p.publishedAt), style: text.labelSmall?.copyWith(color: AppColors.teks2)),
                ],
              ),
              const SizedBox(height: 10),
              Text(p.judul, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(p.isi, maxLines: 3, overflow: TextOverflow.ellipsis, style: text.bodyMedium?.copyWith(color: AppColors.teks2, height: 1.45)),
              if (p.pembuatNama != null) ...[
                const SizedBox(height: 12),
                PembuatPengumuman(pengumuman: p, ukuran: 26),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail pengumuman
// ---------------------------------------------------------------------------

class PengumumanDetailPage extends ConsumerWidget {
  const PengumumanDetailPage({super.key, required this.id});

  final int id;

  Future<void> _hapus(BuildContext context, WidgetRef ref, Pengumuman p) async {
    final ok = await konfirmasi(
      context,
      judul: 'Hapus pengumuman?',
      isi: 'Pengumuman "${p.judul}" akan dihapus untuk semua penerima.',
      ya: 'Hapus',
      bahaya: true,
    );
    if (!ok) return;
    try {
      await ref.read(pengumumanRepositoryProvider).hapus(p.id);
      if (context.mounted) {
        showPesan(context, 'Pengumuman dihapus.');
        context.kembali(true);
      }
    } on ApiException catch (e) {
      if (context.mounted) showPesan(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const SizedBox.shrink();
    final detail = ref.watch(pengumumanDetailProvider(id));
    final text = Theme.of(context).textTheme;
    final p = detail.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengumuman'),
        actions: [
          if (p != null && user.bisaUbahPengumuman(p.pembuatId))
            PopupMenuButton<String>(
              onSelected: (aksi) async {
                if (aksi == 'ubah') {
                  final berubah = await context.push<bool>('/pengumuman/${p.id}/ubah');
                  if (berubah == true) ref.invalidate(pengumumanDetailProvider(id));
                } else if (context.mounted) {
                  await _hapus(context, ref, p);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'ubah', child: Text('Ubah pengumuman')),
                PopupMenuItem(value: 'hapus', child: Text('Hapus pengumuman')),
              ],
            ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(pengumumanDetailProvider(id))),
        data: (p) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Row(children: [
              TargetPill(p.target),
              const SizedBox(width: 8),
              Expanded(child: Text(tanggalWaktu(p.publishedAt), style: text.labelMedium?.copyWith(color: AppColors.teks2))),
            ]),
            const SizedBox(height: 14),
            Text(p.judul, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.25)),
            if (p.pembuatNama != null) ...[
              const SizedBox(height: 12),
              PembuatPengumuman(pengumuman: p, ukuran: 36),
            ],
            const Divider(height: 32),
            SelectableText(p.isi, style: text.bodyLarge?.copyWith(height: 1.6)),
            if (p.lampiranUrl != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => bukaLampiran(
                  context,
                  ref.read(apiClientProvider),
                  p.lampiranUrl!,
                  judul: 'Lampiran',
                  namaFile: 'lampiran-pengumuman-${p.id}',
                ),
                icon: const Icon(Icons.attach_file_rounded),
                label: const Text('Buka lampiran'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Form buat / ubah
// ---------------------------------------------------------------------------

class PengumumanFormPage extends ConsumerStatefulWidget {
  const PengumumanFormPage({super.key, this.id});

  final int? id;

  @override
  ConsumerState<PengumumanFormPage> createState() => _PengumumanFormPageState();
}

class _PengumumanFormPageState extends ConsumerState<PengumumanFormPage> {
  final _form = GlobalKey<FormState>();
  final _judul = TextEditingController();
  final _isi = TextEditingController();
  String _target = 'semua';
  UploadFile? _lampiran;
  bool _adaLampiranLama = false;
  bool _hapusLampiran = false;
  bool _siap = false;
  bool _loading = false;
  Map<String, List<String>> _errors = const {};

  bool get _baru => widget.id == null;

  @override
  void initState() {
    super.initState();
    _isiAwal();
  }

  Future<void> _isiAwal() async {
    if (_baru) {
      setState(() => _siap = true);
      return;
    }
    try {
      final p = await ref.read(pengumumanRepositoryProvider).detail(widget.id!);
      _judul.text = p.judul;
      _isi.text = p.isi;
      setState(() {
        _target = p.target;
        _adaLampiranLama = p.lampiranUrl != null;
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
    _judul.dispose();
    _isi.dispose();
    super.dispose();
  }

  Future<void> _pilihLampiran() async {
    final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf']);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) showPesan(context, 'Ukuran lampiran maksimal 5 MB.', error: true);
      return;
    }
    setState(() {
      _lampiran = UploadFile(f.name, bytes);
      _hapusLampiran = false;
    });
  }

  Future<void> _simpan() async {
    setState(() => _errors = const {});
    if (!_form.currentState!.validate()) return;

    if (_baru) {
      final sasaran = switch (_target) {
        'putra' => 'semua santri putra dan pengurus putra',
        'putri' => 'semua santri putri dan pengurus putri',
        _ => 'semua santri dan pengurus',
      };
      final ok = await konfirmasi(
        context,
        judul: 'Kirim pengumuman?',
        isi: 'Pengumuman akan langsung terkirim sebagai notifikasi ke $sasaran.',
        ya: 'Kirim',
      );
      if (!ok) return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(pengumumanRepositoryProvider).simpan(
            id: widget.id,
            judul: _judul.text.trim(),
            isi: _isi.text.trim(),
            target: _target,
            lampiran: _lampiran,
            hapusLampiran: _hapusLampiran,
          );
      if (!mounted) return;
      showPesan(context, _baru ? 'Pengumuman terkirim.' : 'Pengumuman diperbarui.');
      context.kembali(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errors = e.errors);
      _form.currentState!.validate();
      showPesan(context, e.errors.values.firstOrNull?.first ?? e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<(String, String)> _pilihanTarget(User user) => [
        ('semua', 'Semua'),
        if (user.isAdmin || user.gender == 'L') ('putra', 'Putra'),
        if (user.isAdmin || user.gender == 'P') ('putri', 'Putri'),
      ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(_baru ? 'Buat Pengumuman' : 'Ubah Pengumuman')),
      body: !_siap
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  Text('Ditujukan untuk', style: text.labelLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: [
                      for (final (v, label) in _pilihanTarget(user)) ButtonSegment(value: v, label: Text(label)),
                    ],
                    selected: {_target},
                    onSelectionChanged: (s) => setState(() => _target = s.first),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _judul,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Judul', hintText: 'contoh: Libur Maulid Nabi'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Judul wajib diisi.' : _errors['judul']?.first,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _isi,
                    minLines: 6,
                    maxLines: 14,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Isi pengumuman', alignLabelWithHint: true),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Isi pengumuman wajib diisi.' : _errors['isi']?.first,
                  ),
                  const SizedBox(height: 14),
                  if (_lampiran != null)
                    _LampiranTerpilih(
                      nama: _lampiran!.name,
                      onHapus: () => setState(() => _lampiran = null),
                    )
                  else if (_adaLampiranLama && !_hapusLampiran)
                    _LampiranTerpilih(
                      nama: 'Lampiran saat ini',
                      onHapus: () => setState(() => _hapusLampiran = true),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _pilihLampiran,
                      icon: const Icon(Icons.attach_file_rounded),
                      label: const Text('Tambah lampiran (gambar / PDF)'),
                    ),
                  const SizedBox(height: 24),
                  TombolSimpan(loading: _loading, onPressed: _simpan, label: _baru ? 'Kirim pengumuman' : 'Simpan perubahan'),
                ],
              ),
            ),
    );
  }
}

class _LampiranTerpilih extends StatelessWidget {
  const _LampiranTerpilih({required this.nama, required this.onHapus});

  final String nama;
  final VoidCallback onHapus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(color: AppColors.hijauMuda, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Icon(Icons.attach_file_rounded, color: AppColors.hijau),
          const SizedBox(width: 10),
          Expanded(child: Text(nama, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
          IconButton(tooltip: 'Hapus lampiran', onPressed: onHapus, icon: const Icon(Icons.close_rounded)),
        ],
      ),
    );
  }
}
