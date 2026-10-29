import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/akses.dart';
import '../../models/keuangan.dart';
import '../../models/santri.dart';
import '../../shared/paged_list.dart';
import '../../shared/rupiah_input.dart';
import '../../shared/ui.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';
import '../santri/santri_repository.dart';
import 'keuangan_repository.dart';
import 'keuangan_widgets.dart';
import 'tagihan_santri_page.dart';

// ---------------------------------------------------------------------------
// Daftar tagihan
// ---------------------------------------------------------------------------

class TagihanListPage extends ConsumerStatefulWidget {
  const TagihanListPage({super.key, this.santriId, this.namaSantri});

  /// Jika diisi, hanya tagihan santri ini.
  final int? santriId;
  final String? namaSantri;

  @override
  ConsumerState<TagihanListPage> createState() => _TagihanListPageState();
}

class _TagihanListPageState extends ConsumerState<TagihanListPage> {
  final _cari = TextEditingController();
  Timer? _jeda;
  String _filter = 'belum_lunas';
  String _kataKunci = '';
  int _versi = 0;
  RingkasanTagihan? _ringkasan;

  @override
  void dispose() {
    _jeda?.cancel();
    _cari.dispose();
    super.dispose();
  }

  void _muatUlang() => setState(() => _versi++);

  Future<void> _buka(Tagihan t) async {
    await context.push('/tagihan/${t.id}');
    if (mounted) _muatUlang();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const SizedBox.shrink();
    final repo = ref.read(keuanganRepositoryProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.namaSantri == null ? 'Tagihan' : 'Tagihan ${widget.namaSantri}'),
        actions: [
          if (user.bisaKelolaKeuangan && widget.santriId == null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'Buat tagihan',
              onSelected: (aksi) async {
                if (aksi == 'iuran') {
                  final ok = await context.push<bool>('/tagihan-iuran');
                  if (ok == true) _muatUlang();
                } else {
                  if (await bukaGenerateSpp(context, ref) && mounted) _muatUlang();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'iuran',
                  child: ListTile(leading: Icon(Icons.post_add_rounded), title: Text('Buat iuran'), contentPadding: EdgeInsets.zero),
                ),
                PopupMenuItem(
                  value: 'spp',
                  child: ListTile(leading: Icon(Icons.event_repeat_rounded), title: Text('Buat SPP bulan ini'), contentPadding: EdgeInsets.zero),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          if (widget.santriId == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _cari,
                decoration: const InputDecoration(hintText: 'Cari nama santri, NIS, atau judul', prefixIcon: Icon(Icons.search_rounded)),
                onChanged: (v) {
                  _jeda?.cancel();
                  _jeda = Timer(const Duration(milliseconds: 450), () => setState(() => _kataKunci = v.trim()));
                },
              ),
            ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final (v, label) in [
                  ('belum_lunas', 'Belum lunas'),
                  ('belum_bayar', 'Belum bayar'),
                  ('dicicil', 'Dicicil'),
                  ('lunas', 'Lunas'),
                  ('semua', 'Semua'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _filter == v,
                      showCheckmark: false,
                      selectedColor: AppColors.hijau,
                      labelStyle: TextStyle(color: _filter == v ? Colors.white : AppColors.teks, fontWeight: FontWeight.w600),
                      onSelected: (_) => setState(() => _filter = v),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: PagedList<Tagihan>(
              reloadKey: '$_filter|$_kataKunci|$_versi',
              muat: (page) async {
                final hasil = await repo.tagihan(
                  page: page,
                  santriId: widget.santriId,
                  search: _kataKunci,
                  belumLunas: _filter == 'belum_lunas',
                  status: const ['belum_bayar', 'dicicil', 'lunas'].contains(_filter) ? _filter : null,
                );
                if (page == 1 && mounted) setState(() => _ringkasan = hasil.ringkasan);
                return hasil.halaman;
              },
              header: _ringkasan == null || _ringkasan!.jumlah == 0
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Text('${angka(_ringkasan!.jumlah)} tagihan', style: text.labelMedium?.copyWith(color: AppColors.teks2)),
                          const Spacer(),
                          Text(
                            'Sisa ${rupiah(_ringkasan!.sisa)}',
                            style: text.labelLarge?.copyWith(
                              color: _ringkasan!.sisa > 0 ? AppColors.merah : AppColors.hijau,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
              itemBuilder: (_, t) => TagihanCard(tagihan: t, tampilSantri: widget.santriId == null, onTap: () => _buka(t)),
              kosong: EmptyView(
                icon: Icons.receipt_long_outlined,
                judul: _filter == 'belum_lunas' ? 'Tidak ada tunggakan' : 'Belum ada tagihan',
                isi: _filter == 'belum_lunas' ? 'Semua tagihan sudah lunas.' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog membuat tagihan SPP untuk satu bulan. Mengembalikan true jika berhasil.
Future<bool> bukaGenerateSpp(BuildContext context, WidgetRef ref) async {
  var bulan = DateTime(DateTime.now().year, DateTime.now().month);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Buat tagihan SPP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SPP biasanya dibuat otomatis setiap tanggal 1. Gunakan ini jika perlu membuat manual. '
              'Santri yang sudah punya tagihan SPP di bulan itu tidak akan dibuatkan lagi.',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => bulan = DateTime(bulan.year, bulan.month - 1)),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy', 'id_ID').format(bulan),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => bulan = DateTime(bulan.year, bulan.month + 1)),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Buat SPP'),
          ),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return false;

  try {
    final pesan = await ref.read(keuanganRepositoryProvider).generateSpp(periode: DateFormat('yyyy-MM').format(bulan));
    if (context.mounted) showPesan(context, pesan);
    return true;
  } on ApiException catch (e) {
    if (context.mounted) showPesan(context, e.message, error: true);
    return false;
  }
}

// ---------------------------------------------------------------------------
// Detail tagihan
// ---------------------------------------------------------------------------

class TagihanDetailPage extends ConsumerWidget {
  const TagihanDetailPage({super.key, required this.id});

  final int id;

  void _segarkan(WidgetRef ref) {
    ref.invalidate(tagihanDetailProvider(id));
    ref.invalidate(saldoKasProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const SizedBox.shrink();
    final detail = ref.watch(tagihanDetailProvider(id));
    final text = Theme.of(context).textTheme;
    final t = detail.value;
    final bolehUbah = t != null && user.bisaKelolaKeuangan;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Tagihan'),
        actions: [
          if (bolehUbah)
            PopupMenuButton<String>(
              onSelected: (aksi) async {
                if (aksi == 'ubah') {
                  final ok = await bukaSheet<bool>(context, judul: 'Ubah tagihan', child: _UbahTagihanForm(tagihan: t));
                  if (ok == true) _segarkan(ref);
                  return;
                }
                final yakin = await konfirmasi(
                  context,
                  judul: 'Hapus tagihan?',
                  isi: 'Tagihan "${t.judul}" akan dihapus. Tagihan yang sudah memiliki pembayaran tidak dapat dihapus.',
                  ya: 'Hapus',
                  bahaya: true,
                );
                if (!yakin) return;
                try {
                  await ref.read(keuanganRepositoryProvider).hapusTagihan(t.id);
                  if (context.mounted) {
                    showPesan(context, 'Tagihan dihapus.');
                    context.kembali();
                  }
                } on ApiException catch (e) {
                  if (context.mounted) showPesan(context, e.message, error: true);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'ubah', child: Text('Ubah tagihan')),
                PopupMenuItem(value: 'hapus', child: Text('Hapus tagihan')),
              ],
            ),
        ],
      ),
      bottomNavigationBar: switch (t) {
        final t? when !t.lunas && t.bisaDibayar == 0 => SafeArea(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.oranyeMuda, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded, color: AppColors.oranye),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pembayaran ${rupiah(t.menunggu)} sedang menunggu verifikasi bendahara.',
                      style: text.bodySmall?.copyWith(color: AppColors.oranye, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        final t? when !t.lunas && (user.bisaKelolaKeuangan || user.isSantri) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                onPressed: () async {
                  final ok = await bukaSheet<bool>(
                    context,
                    judul: user.isSantri ? 'Kirim bukti pembayaran' : 'Catat pembayaran',
                    child: user.isSantri ? UploadBuktiForm(tagihan: t, maks: t.bisaDibayar) : InputPembayaranForm(tagihan: t),
                  );
                  if (ok == true) _segarkan(ref);
                },
                icon: Icon(user.isSantri ? Icons.upload_rounded : Icons.payments_rounded),
                label: Text(user.isSantri ? 'Kirim bukti pembayaran' : 'Catat pembayaran'),
              ),
            ),
          ),
        _ => null,
      },
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => _segarkan(ref)),
        data: (t) {
          final rasio = t.nominal == 0 ? 1.0 : (t.terbayar / t.nominal).clamp(0.0, 1.0);
          return RefreshIndicator(
            onRefresh: () => ref.refresh(tagihanDetailProvider(id).future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(t.judul, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                          StatusTagihanPill(t.status),
                        ],
                      ),
                      if (t.santri != null) ...[
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: user.bisaLihatKeuangan ? () => context.push('/santri/${t.santri!.id}') : null,
                          child: Text(
                            '${t.santri!.namaLengkap} · NIS ${t.santri!.nis}',
                            style: text.bodyMedium?.copyWith(color: AppColors.hijau, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(t.lunas ? 'Lunas' : 'Sisa tagihan', style: text.labelLarge?.copyWith(color: AppColors.teks2)),
                      Text(
                        rupiah(t.lunas ? t.nominal : t.sisa),
                        style: text.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: t.lunas ? AppColors.hijau : AppColors.merah,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: rasio,
                          minHeight: 8,
                          backgroundColor: AppColors.merahMuda,
                          color: t.lunas ? AppColors.hijau : AppColors.oranye,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InfoBaris('Nominal tagihan', rupiah(t.nominal)),
                      InfoBaris('Sudah dibayar', rupiah(t.terbayar)),
                      if (t.jenis != null) InfoBaris('Jenis', '${t.jenis!.nama} (${t.jenis!.spp ? 'SPP' : 'Iuran'})'),
                      if (t.jatuhTempo != null)
                        InfoBaris('Jatuh tempo', tanggal(t.jatuhTempo), warna: t.lewatJatuhTempo ? AppColors.merah : null),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Riwayat pembayaran',
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: t.pembayaran.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text('Belum ada pembayaran.', style: text.bodyMedium?.copyWith(color: AppColors.teks2)),
                        )
                      : Column(
                          children: [
                            for (final p in t.pembayaran)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                onTap: () async {
                                  final berubah = await context.push<bool>('/pembayaran/${p.id}');
                                  if (berubah == true) _segarkan(ref);
                                },
                                title: Text(rupiah(p.nominal), style: const TextStyle(fontWeight: FontWeight.w800)),
                                subtitle: Text('${p.metodeLabel} · ${tanggal(p.tanggalBayar)}'),
                                trailing: StatusPembayaranPill(p.status),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Bendahara/admin mencatat pembayaran yang diterima langsung (tunai / transfer ke rekening bendahara).
class InputPembayaranForm extends ConsumerStatefulWidget {
  const InputPembayaranForm({super.key, required this.tagihan});

  final Tagihan tagihan;

  @override
  ConsumerState<InputPembayaranForm> createState() => _InputPembayaranFormState();
}

class _InputPembayaranFormState extends ConsumerState<InputPembayaranForm> {
  final _form = GlobalKey<FormState>();
  late final _nominal = TextEditingController(text: tulisRupiah(widget.tagihan.bisaDibayar));
  final _catatan = TextEditingController();
  String _metode = 'tunai';
  DateTime _tanggal = DateTime.now();
  UploadFile? _bukti;
  bool _loading = false;
  String? _errorNominal;

  @override
  void dispose() {
    _nominal.dispose();
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    setState(() => _errorNominal = null);
    if (!_form.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final pesan = await ref.read(keuanganRepositoryProvider).bayar(
            tagihanId: widget.tagihan.id,
            nominal: bacaRupiah(_nominal.text)!,
            metode: _metode,
            tanggalBayar: isoTanggal(_tanggal),
            catatan: _catatan.text.trim(),
            bukti: _bukti,
          );
      if (!mounted) return;
      showPesan(context, pesan);
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorNominal = e.fieldError('nominal'));
      _form.currentState!.validate();
      if (e.fieldError('nominal') == null) showPesan(context, e.errors.values.firstOrNull?.first ?? e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.tagihan.judul} · bisa dibayar hingga ${rupiah(widget.tagihan.bisaDibayar)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.teks2),
          ),
          const SizedBox(height: 16),
          RupiahField(
            controller: _nominal,
            label: 'Nominal diterima',
            maks: widget.tagihan.bisaDibayar,
            helper: 'Boleh kurang dari sisa jika pembayaran dicicil.',
            errorServer: _errorNominal,
          ),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'tunai', label: Text('Tunai'), icon: Icon(Icons.payments_outlined)),
              ButtonSegment(value: 'transfer', label: Text('Transfer'), icon: Icon(Icons.account_balance_outlined)),
            ],
            selected: {_metode},
            onSelectionChanged: (s) => setState(() => _metode = s.first),
          ),
          const SizedBox(height: 14),
          TanggalField(
            label: 'Tanggal diterima',
            value: _tanggal,
            lastDate: DateTime.now(),
            onChanged: (d) => setState(() => _tanggal = d ?? _tanggal),
          ),
          const SizedBox(height: 14),
          TextFormField(controller: _catatan, decoration: const InputDecoration(labelText: 'Catatan (opsional)')),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1400, imageQuality: 80);
              if (x != null) {
                final b = UploadFile(x.name, await x.readAsBytes());
                setState(() => _bukti = b);
              }
            },
            icon: Icon(_bukti == null ? Icons.add_photo_alternate_outlined : Icons.check_circle_rounded),
            label: Text(_bukti == null ? 'Lampirkan bukti (opsional)' : 'Bukti terlampir: ${_bukti!.name}', overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 16),
          TombolSimpan(loading: _loading, onPressed: _simpan, label: 'Simpan pembayaran'),
          const SizedBox(height: 8),
          Text(
            'Pembayaran yang dicatat bendahara langsung disetujui dan masuk ke kas.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.teks2),
          ),
        ],
      ),
    );
  }
}

class _UbahTagihanForm extends ConsumerStatefulWidget {
  const _UbahTagihanForm({required this.tagihan});

  final Tagihan tagihan;

  @override
  ConsumerState<_UbahTagihanForm> createState() => _UbahTagihanFormState();
}

class _UbahTagihanFormState extends ConsumerState<_UbahTagihanForm> {
  final _form = GlobalKey<FormState>();
  late final _judul = TextEditingController(text: widget.tagihan.judul);
  late final _nominal = TextEditingController(text: tulisRupiah(widget.tagihan.nominal));
  late DateTime? _jatuhTempo = widget.tagihan.jatuhTempo == null ? null : DateTime.tryParse(widget.tagihan.jatuhTempo!);
  bool _loading = false;

  @override
  void dispose() {
    _judul.dispose();
    _nominal.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(keuanganRepositoryProvider).ubahTagihan(
            widget.tagihan.id,
            judul: _judul.text.trim(),
            nominal: bacaRupiah(_nominal.text)!,
            jatuhTempo: _jatuhTempo == null ? null : isoTanggal(_jatuhTempo!),
          );
      if (mounted) {
        showPesan(context, 'Tagihan diperbarui.');
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) showPesan(context, e.errors.values.firstOrNull?.first ?? e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _judul,
            decoration: const InputDecoration(labelText: 'Judul tagihan'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Judul wajib diisi.' : null,
          ),
          const SizedBox(height: 14),
          RupiahField(
            controller: _nominal,
            label: 'Nominal',
            helper: 'Tidak boleh kurang dari yang sudah dibayar (${rupiah(widget.tagihan.terbayar)}).',
          ),
          const SizedBox(height: 14),
          TanggalField(label: 'Jatuh tempo', value: _jatuhTempo, wajib: false, onChanged: (d) => setState(() => _jatuhTempo = d)),
          const SizedBox(height: 20),
          TombolSimpan(loading: _loading, onPressed: _simpan),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Buat iuran
// ---------------------------------------------------------------------------

class BuatIuranPage extends ConsumerStatefulWidget {
  const BuatIuranPage({super.key});

  @override
  ConsumerState<BuatIuranPage> createState() => _BuatIuranPageState();
}

class _BuatIuranPageState extends ConsumerState<BuatIuranPage> {
  final _form = GlobalKey<FormState>();
  final _judul = TextEditingController();
  final _nominal = TextEditingController();
  JenisTagihan? _jenis;
  DateTime? _jatuhTempo;
  String? _sasaran; // null = putra & putri (admin)
  bool _tertentu = false;
  final _dipilih = <int, Santri>{};
  bool _loading = false;

  @override
  void dispose() {
    _judul.dispose();
    _nominal.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (_jenis == null) {
      showPesan(context, 'Pilih jenis iuran.', error: true);
      return;
    }
    if (!_form.currentState!.validate()) return;
    if (_tertentu && _dipilih.isEmpty) {
      showPesan(context, 'Pilih minimal satu santri.', error: true);
      return;
    }

    final user = ref.read(authControllerProvider).value!;
    final sasaran = _tertentu
        ? '${_dipilih.length} santri yang dipilih'
        : 'semua santri aktif ${user.isAdmin ? (_sasaran == null ? 'putra & putri' : (_sasaran == 'L' ? 'putra' : 'putri')) : user.genderLabel!.toLowerCase()}';
    final ok = await konfirmasi(
      context,
      judul: 'Buat tagihan iuran?',
      isi: 'Tagihan "${_judul.text.trim().isEmpty ? _jenis!.nama : _judul.text.trim()}" sebesar ${rupiah(bacaRupiah(_nominal.text))} '
          'akan dibuat untuk $sasaran, dan setiap santri menerima notifikasi.',
      ya: 'Buat tagihan',
    );
    if (!ok) return;

    setState(() => _loading = true);
    try {
      final pesan = await ref.read(keuanganRepositoryProvider).buatIuran(
            jenisTagihanId: _jenis!.id,
            judul: _judul.text.trim(),
            nominal: bacaRupiah(_nominal.text),
            jatuhTempo: _jatuhTempo == null ? null : isoTanggal(_jatuhTempo!),
            gender: user.isAdmin && !_tertentu ? _sasaran : null,
            santriIds: _tertentu ? _dipilih.keys.toList() : null,
          );
      if (!mounted) return;
      showPesan(context, pesan);
      context.kembali(true);
    } on ApiException catch (e) {
      if (mounted) showPesan(context, e.errors.values.firstOrNull?.first ?? e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pilihSantri() async {
    final hasil = await bukaSheet<Map<int, Santri>>(context, judul: 'Pilih santri', child: _PilihSantriSheet(awal: _dipilih));
    if (hasil != null) {
      setState(() => _dipilih
        ..clear()
        ..addAll(hasil));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const SizedBox.shrink();
    final jenis = ref.watch(jenisTagihanProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Buat Iuran')),
      body: jenis.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(jenisTagihanProvider)),
        data: (daftar) {
          final iuran = daftar.where((j) => !j.spp && j.isActive).toList();
          if (iuran.isEmpty) {
            return EmptyView(
              icon: Icons.category_outlined,
              judul: 'Belum ada jenis iuran',
              isi: 'Tambahkan jenis iuran (misalnya Iuran Ziarah) di menu Jenis Tagihan.',
              aksi: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(200, 48)),
                onPressed: () => context.pushReplacement('/jenis-tagihan'),
                child: const Text('Buka Jenis Tagihan'),
              ),
            );
          }

          return Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                Text(
                  'Tagihan dibuat untuk semua santri aktif, atau hanya santri yang dipilih '
                  '(misalnya santri baru atau tunggakan sebelum aplikasi dipakai).',
                  style: text.bodyMedium?.copyWith(color: AppColors.teks2),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<JenisTagihan>(
                  initialValue: _jenis,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Jenis iuran', prefixIcon: Icon(Icons.category_outlined)),
                  items: [for (final j in iuran) DropdownMenuItem(value: j, child: Text('${j.nama} · ${rupiah(j.nominal)}'))],
                  onChanged: (j) => setState(() {
                    _jenis = j;
                    _nominal.text = tulisRupiah(j?.nominal);
                    if (_judul.text.isEmpty && j != null) _judul.text = j.nama;
                  }),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _judul,
                  decoration: const InputDecoration(labelText: 'Judul tagihan', hintText: 'contoh: Iuran Ziarah Wali Songo 2026'),
                ),
                const SizedBox(height: 14),
                RupiahField(controller: _nominal, label: 'Nominal per santri'),
                const SizedBox(height: 14),
                TanggalField(label: 'Jatuh tempo (opsional)', value: _jatuhTempo, wajib: false, onChanged: (d) => setState(() => _jatuhTempo = d)),
                const SizedBox(height: 18),
                Text('Untuk santri', style: text.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (tertentu, v, label) in <(bool, String?, String)>[
                      if (user.isAdmin) ...[(false, null, 'Putra & putri'), (false, 'L', 'Putra saja'), (false, 'P', 'Putri saja')]
                      else (false, null, 'Semua santri ${user.genderLabel!.toLowerCase()}'),
                      (true, null, 'Santri tertentu'),
                    ])
                      ChoiceChip(
                        label: Text(label),
                        selected: _tertentu == tertentu && (tertentu || _sasaran == v),
                        showCheckmark: false,
                        selectedColor: AppColors.hijau,
                        labelStyle: TextStyle(
                          color: _tertentu == tertentu && (tertentu || _sasaran == v) ? Colors.white : AppColors.teks,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) => setState(() {
                          _tertentu = tertentu;
                          if (!tertentu) _sasaran = v;
                        }),
                      ),
                  ],
                ),
                if (_tertentu) ...[
                  const SizedBox(height: 12),
                  if (_dipilih.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final s in _dipilih.values)
                          InputChip(label: Text(s.namaLengkap), onDeleted: () => setState(() => _dipilih.remove(s.id))),
                      ],
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pilihSantri,
                    icon: const Icon(Icons.person_search_rounded),
                    label: Text(_dipilih.isEmpty ? 'Pilih santri' : 'Ubah pilihan (${_dipilih.length})'),
                  ),
                ],
                const SizedBox(height: 24),
                TombolSimpan(loading: _loading, onPressed: _simpan, label: 'Buat tagihan iuran'),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Lembar pencarian santri aktif dengan pilihan ganda. Mengembalikan santri yang dipilih.
class _PilihSantriSheet extends ConsumerStatefulWidget {
  const _PilihSantriSheet({required this.awal});

  final Map<int, Santri> awal;

  @override
  ConsumerState<_PilihSantriSheet> createState() => _PilihSantriSheetState();
}

class _PilihSantriSheetState extends ConsumerState<_PilihSantriSheet> {
  late final _dipilih = Map<int, Santri>.of(widget.awal);
  Timer? _jeda;
  late Future<Halaman<Santri>> _hasil = _cari('');

  Future<Halaman<Santri>> _cari(String kata) => ref.read(santriRepositoryProvider).daftar(search: kata);

  @override
  void dispose() {
    _jeda?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Cari nama atau NIS', prefixIcon: Icon(Icons.search_rounded)),
          onChanged: (v) {
            _jeda?.cancel();
            _jeda = Timer(const Duration(milliseconds: 450), () => setState(() => _hasil = _cari(v.trim())));
          },
        ),
        const SizedBox(height: 8),
        FutureBuilder<Halaman<Santri>>(
          future: _hasil,
          builder: (context, snap) {
            if (snap.hasError) return Text('${snap.error}', style: const TextStyle(color: AppColors.merah));
            if (!snap.hasData) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
            final halaman = snap.data!;
            if (halaman.items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Santri tidak ditemukan.', textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: AppColors.teks2)),
              );
            }
            return Column(
              children: [
                for (final s in halaman.items)
                  CheckboxListTile(
                    value: _dipilih.containsKey(s.id),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.hijau,
                    title: Text(s.namaLengkap, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('NIS ${s.nis}'),
                    onChanged: (v) => setState(() => v == true ? _dipilih[s.id] = s : _dipilih.remove(s.id)),
                  ),
                if (halaman.adaLagi)
                  Text('Ketik nama untuk mencari santri lainnya.', style: text.labelSmall?.copyWith(color: AppColors.teks2)),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: () => Navigator.pop(context, _dipilih),
          child: Text(_dipilih.isEmpty ? 'Selesai' : 'Pilih ${_dipilih.length} santri'),
        ),
      ],
    );
  }
}
