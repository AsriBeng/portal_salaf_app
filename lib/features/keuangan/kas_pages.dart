import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/akses.dart';
import '../../models/keuangan.dart';
import '../../models/user.dart' show User;
import '../../shared/paged_list.dart';
import '../../shared/rupiah_input.dart';
import '../../shared/ui.dart';
import '../auth/auth_controller.dart';
import '../komplek/komplek_forms.dart';
import '../komplek/komplek_pages.dart';
import 'keuangan_repository.dart';
import 'keuangan_widgets.dart';

/// Kartu saldo kas (dipakai di beranda keuangan dan halaman kas).
class SaldoKasCard extends ConsumerWidget {
  const SaldoKasCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const SizedBox.shrink();
    final saldo = ref.watch(saldoKasProvider);
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: AppColors.gradien, borderRadius: BorderRadius.circular(22)),
      child: saldo.when(
        loading: () => const SizedBox(height: 90, child: Center(child: CircularProgressIndicator(color: AppColors.emas))),
        error: (e, _) => Text('$e', style: const TextStyle(color: Colors.white)),
        data: (s) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, color: AppColors.emas, size: 20),
                const SizedBox(width: 8),
                Text(
                  user.isAdmin
                      ? 'Saldo kas pondok'
                      : 'Saldo kas ${user.genderLabel?.toLowerCase() ?? ''}',
                  style: text.labelLarge?.copyWith(color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(rupiah(s.total), style: text.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
            if (s.putra != null && s.putri != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _Bagian('Kas putra', s.putra!)),
                  Container(width: 1, height: 34, color: Colors.white24),
                  const SizedBox(width: 16),
                  Expanded(child: _Bagian('Kas putri', s.putri!)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Bagian extends StatelessWidget {
  const _Bagian(this.label, this.nilai);

  final String label;
  final int nilai;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.labelMedium?.copyWith(color: Colors.white60)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(rupiah(nilai), style: text.titleMedium?.copyWith(color: AppColors.emas, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Halaman kas
// ---------------------------------------------------------------------------

class KasPage extends ConsumerStatefulWidget {
  const KasPage({super.key});

  @override
  ConsumerState<KasPage> createState() => _KasPageState();
}

class _KasPageState extends ConsumerState<KasPage> {
  String? _tipe;
  String? _gender;
  int _versi = 0;

  void _muatUlang() {
    setState(() => _versi++);
    ref.invalidate(saldoKasProvider);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const SizedBox.shrink();
    final repo = ref.read(keuanganRepositoryProvider);

    Widget chip(String label, bool aktif, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label),
            selected: aktif,
            showCheckmark: false,
            selectedColor: AppColors.hijau,
            labelStyle: TextStyle(color: aktif ? Colors.white : AppColors.teks, fontWeight: FontWeight.w600),
            onSelected: (_) => onTap(),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Kas')),
      floatingActionButton: user.bisaKelolaKeuangan
          ? FloatingActionButton.extended(
              onPressed: () async {
                final ok = await context.push<bool>('/kas-baru');
                if (ok == true) _muatUlang();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Catat kas'),
            )
          : null,
      body: PagedList<KasTransaksi>(
        reloadKey: '$_tipe|$_gender|$_versi',
        muat: (page) => repo.kas(page: page, tipe: _tipe, gender: _gender),
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SaldoKasCard(),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  chip('Semua', _tipe == null, () => setState(() => _tipe = null)),
                  chip('Masuk', _tipe == 'masuk', () => setState(() => _tipe = 'masuk')),
                  chip('Keluar', _tipe == 'keluar', () => setState(() => _tipe = 'keluar')),
                  if (user.isAdmin) ...[
                    const SizedBox(width: 8),
                    chip('Putra & putri', _gender == null, () => setState(() => _gender = null)),
                    chip('Putra', _gender == 'L', () => setState(() => _gender = 'L')),
                    chip('Putri', _gender == 'P', () => setState(() => _gender = 'P')),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
        itemBuilder: (_, k) => _KasTile(
          kas: k,
          tampilGender: user.isAdmin,
          onTap: () async {
            final hapus = await _detail(context, k, user);
            if (hapus == true) _muatUlang();
          },
        ),
        kosong: const EmptyView(icon: Icons.receipt_long_outlined, judul: 'Belum ada transaksi kas'),
        separator: 8,
      ),
    );
  }

  /// Bottom sheet detail transaksi; mengembalikan true jika transaksi dihapus.
  Future<bool?> _detail(BuildContext context, KasTransaksi k, User user) {
    final headers = ref.read(apiClientProvider).authHeaders;
    return bukaSheet<bool>(
      context,
      judul: k.masuk ? 'Pemasukan' : 'Pengeluaran',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${k.masuk ? '+' : '−'} ${rupiah(k.nominal)}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: k.masuk ? AppColors.hijau : AppColors.merah,
                ),
          ),
          const SizedBox(height: 12),
          InfoBaris('Tanggal', tanggal(k.tanggal)),
          InfoBaris('Kategori', k.kategori?.nama ?? '-'),
          InfoBaris('Kas', k.gender == 'P' ? 'Putri' : 'Putra'),
          InfoBaris('Keterangan', k.keterangan),
          if (k.pembuat != null) InfoBaris('Dicatat oleh', k.pembuat!),
          if (k.buktiUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                k.buktiUrl!,
                headers: headers,
                height: 220,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Text('Bukti berupa PDF atau tidak dapat ditampilkan.'),
              ),
            ),
          ],
          if (k.otomatis) ...[
            const SizedBox(height: 12),
            Text(
              'Tercatat otomatis dari pembayaran santri.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.teks2),
            ),
          ] else if (user.bisaKelolaKeuangan) ...[
            const SizedBox(height: 20),
            Builder(
              builder: (sheet) => OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.merah),
                onPressed: () async {
                  final ok = await konfirmasi(
                    sheet,
                    judul: 'Hapus transaksi?',
                    isi: 'Gunakan hanya jika transaksi ini salah input.',
                    ya: 'Hapus',
                    bahaya: true,
                  );
                  if (!ok) return;
                  try {
                    await ref.read(keuanganRepositoryProvider).hapusKas(k.id);
                    if (sheet.mounted) {
                      showPesan(sheet, 'Transaksi dihapus.');
                      Navigator.pop(sheet, true);
                    }
                  } on ApiException catch (e) {
                    if (sheet.mounted) showPesan(sheet, e.message, error: true);
                  }
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Hapus transaksi'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _KasTile extends StatelessWidget {
  const _KasTile({required this.kas, required this.onTap, required this.tampilGender});

  final KasTransaksi kas;
  final VoidCallback onTap;
  final bool tampilGender;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final k = kas;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: k.masuk ? AppColors.hijauMuda : AppColors.merahMuda,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  k.masuk ? Icons.south_west_rounded : Icons.north_east_rounded,
                  color: k.masuk ? AppColors.hijau : AppColors.merah,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      k.keterangan,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${k.kategori?.nama ?? '-'} · ${tanggal(k.tanggal)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: AppColors.teks2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${k.masuk ? '+' : '−'}${rupiah(k.nominal)}',
                    style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w800, color: k.masuk ? AppColors.hijau : AppColors.merah),
                  ),
                  if (tampilGender) ...[const SizedBox(height: 4), GenderPill(k.gender)],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Form catat kas
// ---------------------------------------------------------------------------

class KasFormPage extends ConsumerStatefulWidget {
  const KasFormPage({super.key});

  @override
  ConsumerState<KasFormPage> createState() => _KasFormPageState();
}

class _KasFormPageState extends ConsumerState<KasFormPage> {
  final _form = GlobalKey<FormState>();
  final _nominal = TextEditingController();
  final _keterangan = TextEditingController();
  String _tipe = 'keluar';
  KategoriKas? _kategori;
  DateTime _tanggal = DateTime.now();
  String? _gender;
  UploadFile? _bukti;
  bool _loading = false;
  Map<String, List<String>> _errors = const {};

  @override
  void dispose() {
    _nominal.dispose();
    _keterangan.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final user = ref.read(authControllerProvider).value!;
    setState(() => _errors = const {});
    if (user.isAdmin && _gender == null) {
      showPesan(context, 'Pilih kas putra atau putri.', error: true);
      return;
    }
    if (_kategori == null) {
      showPesan(context, 'Pilih kategori.', error: true);
      return;
    }
    if (!_form.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await ref.read(keuanganRepositoryProvider).catatKas(
            tipe: _tipe,
            kategoriId: _kategori!.id,
            nominal: bacaRupiah(_nominal.text)!,
            keterangan: _keterangan.text.trim(),
            tanggal: isoTanggal(_tanggal),
            gender: user.isAdmin ? _gender : null,
            bukti: _bukti,
          );
      if (!mounted) return;
      showPesan(context, _tipe == 'keluar' ? 'Pengeluaran dicatat. Saldo kas berkurang.' : 'Pemasukan dicatat.');
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const SizedBox.shrink();
    final kategori = ref.watch(kategoriKasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Catat Kas')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'keluar', label: Text('Pengeluaran'), icon: Icon(Icons.north_east_rounded)),
                ButtonSegment(value: 'masuk', label: Text('Pemasukan lain'), icon: Icon(Icons.south_west_rounded)),
              ],
              selected: {_tipe},
              onSelectionChanged: (s) => setState(() {
                _tipe = s.first;
                _kategori = null;
              }),
            ),
            const SizedBox(height: 16),
            if (user.isAdmin) ...[
              Text('Kas', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              PilihGender(value: _gender, onChanged: (g) => setState(() => _gender = g)),
              const SizedBox(height: 16),
            ],
            kategori.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (daftar) {
                final pilihan = daftar.where((k) => k.tipe == _tipe && !k.sistem).toList();
                return DropdownButtonFormField<KategoriKas>(
                  key: ValueKey(_tipe),
                  initialValue: _kategori,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Kategori',
                    prefixIcon: const Icon(Icons.label_outline_rounded),
                    helperText: pilihan.isEmpty ? 'Belum ada kategori. Tambahkan di menu Kategori Kas.' : null,
                  ),
                  items: [for (final k in pilihan) DropdownMenuItem(value: k, child: Text(k.nama))],
                  onChanged: (k) => setState(() => _kategori = k),
                );
              },
            ),
            const SizedBox(height: 14),
            RupiahField(controller: _nominal, errorServer: _errors['nominal']?.first),
            const SizedBox(height: 14),
            TextFormField(
              controller: _keterangan,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Keterangan', hintText: 'contoh: Beli beras 50 kg'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Keterangan wajib diisi.' : _errors['keterangan']?.first,
            ),
            const SizedBox(height: 14),
            TanggalField(label: 'Tanggal', value: _tanggal, lastDate: DateTime.now(), onChanged: (d) => setState(() => _tanggal = d ?? _tanggal)),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf']);
                if (f != null) {
                  final b = UploadFile(f.name, await f.readAsBytes());
                  setState(() => _bukti = b);
                }
              },
              icon: Icon(_bukti == null ? Icons.attach_file_rounded : Icons.check_circle_rounded),
              label: Text(_bukti == null ? 'Lampirkan nota / bukti (opsional)' : _bukti!.name, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 20),
            TombolSimpan(loading: _loading, onPressed: _simpan, label: _tipe == 'keluar' ? 'Simpan pengeluaran' : 'Simpan pemasukan'),
            if (_tipe == 'keluar') ...[
              const SizedBox(height: 8),
              Text(
                'Pengeluaran langsung memotong saldo kas dan tidak bisa melebihi saldo.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.teks2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
