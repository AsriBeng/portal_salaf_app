import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/akses.dart';
import '../../models/keuangan.dart';
import '../../shared/rupiah_input.dart';
import '../../shared/ui.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';
import 'keuangan_repository.dart';
import 'keuangan_widgets.dart';
import 'spp_khusus.dart';

// ---------------------------------------------------------------------------
// Jenis tagihan (SPP & iuran)
// ---------------------------------------------------------------------------

class JenisTagihanPage extends ConsumerWidget {
  const JenisTagihanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const SizedBox.shrink();
    final daftar = ref.watch(jenisTagihanProvider);
    final text = Theme.of(context).textTheme;

    Future<void> buka([JenisTagihan? j]) async {
      final ok = await bukaSheet<bool>(
        context,
        judul: j == null ? 'Tambah jenis tagihan' : 'Ubah ${j.nama}',
        child: _JenisForm(jenis: j),
      );
      if (ok == true) ref.invalidate(jenisTagihanProvider);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Jenis Tagihan')),
      floatingActionButton: user.bisaKelolaKeuangan
          ? FloatingActionButton.extended(onPressed: buka, icon: const Icon(Icons.add_rounded), label: const Text('Jenis'))
          : null,
      body: daftar.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(jenisTagihanProvider)),
        data: (items) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.emasMuda, borderRadius: BorderRadius.circular(14)),
              child: Text(
                'SPP dibuat otomatis tiap tanggal 1 untuk semua santri aktif dengan nominal di bawah. '
                'Jika nominal SPP masih Rp 0, tagihan SPP tidak dibuat. Perubahan nominal berlaku untuk bulan berikutnya.',
                style: text.bodySmall?.copyWith(color: const Color(0xFF6B5500), height: 1.45),
              ),
            ),
            const SizedBox(height: 14),
            for (final j in items) ...[
              Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  onTap: user.bisaKelolaKeuangan ? () => buka(j) : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: j.spp ? AppColors.hijauMuda : AppColors.biruMuda,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(j.spp ? Icons.event_repeat_rounded : Icons.category_outlined,
                        color: j.spp ? AppColors.hijau : AppColors.biru),
                  ),
                  title: Text(j.nama, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${j.spp ? 'SPP bulanan' : 'Iuran'}${j.isActive ? '' : ' · nonaktif'}'),
                  trailing: Text(
                    rupiah(j.nominal),
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: j.spp && j.nominal == 0 ? AppColors.merah : AppColors.teks,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            SppKhususSection(bisaKelola: user.bisaKelolaKeuangan),
          ],
        ),
      ),
    );
  }
}

class _JenisForm extends ConsumerStatefulWidget {
  const _JenisForm({this.jenis});

  final JenisTagihan? jenis;

  @override
  ConsumerState<_JenisForm> createState() => _JenisFormState();
}

class _JenisFormState extends ConsumerState<_JenisForm> {
  final _form = GlobalKey<FormState>();
  late final _nama = TextEditingController(text: widget.jenis?.nama);
  late final _nominal = TextEditingController(text: tulisRupiah(widget.jenis?.nominal));
  late bool _aktif = widget.jenis?.isActive ?? true;
  bool _loading = false;

  @override
  void dispose() {
    _nama.dispose();
    _nominal.dispose();
    super.dispose();
  }

  Future<void> _jalankan(Future<void> Function() aksi, String pesan) async {
    setState(() => _loading = true);
    try {
      await aksi();
      if (mounted) {
        showPesan(context, pesan);
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
    final repo = ref.read(keuanganRepositoryProvider);
    final j = widget.jenis;

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (j == null)
            Text('Jenis baru dibuat sebagai iuran (misalnya Iuran Ziarah, Iuran Haflah).',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.teks2)),
          if (j == null) const SizedBox(height: 14),
          TextFormField(
            controller: _nama,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nama'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi.' : null,
          ),
          const SizedBox(height: 14),
          RupiahField(
            controller: _nominal,
            label: j?.spp == true ? 'Nominal SPP per bulan' : 'Nominal bawaan',
          ),
          if (j != null && !j.spp) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              value: _aktif,
              onChanged: (v) => setState(() => _aktif = v),
              contentPadding: EdgeInsets.zero,
              title: const Text('Aktif'),
              subtitle: const Text('Jenis nonaktif tidak muncul saat membuat iuran.'),
            ),
          ],
          const SizedBox(height: 18),
          TombolSimpan(
            loading: _loading,
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              _jalankan(
                () => repo.simpanJenisTagihan(
                  id: j?.id,
                  nama: _nama.text.trim(),
                  tipe: j == null ? 'iuran' : null,
                  nominal: bacaRupiah(_nominal.text)!,
                  aktif: j == null || j.spp ? null : _aktif,
                ),
                'Jenis tagihan disimpan.',
              );
            },
          ),
          if (j != null && !j.spp) ...[
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.merah),
              onPressed: _loading
                  ? null
                  : () async {
                      final ok = await konfirmasi(
                        context,
                        judul: 'Hapus ${j.nama}?',
                        isi: 'Jika jenis ini sudah pernah dipakai, ia hanya akan dinonaktifkan.',
                        ya: 'Hapus',
                        bahaya: true,
                      );
                      if (!ok) return;
                      setState(() => _loading = true);
                      try {
                        final pesan = await repo.hapusJenisTagihan(j.id);
                        if (context.mounted) {
                          showPesan(context, pesan);
                          Navigator.pop(context, true);
                        }
                      } on ApiException catch (e) {
                        if (context.mounted) showPesan(context, e.message, error: true);
                      } finally {
                        if (mounted) setState(() => _loading = false);
                      }
                    },
              child: const Text('Hapus jenis ini'),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kategori kas
// ---------------------------------------------------------------------------

class KategoriKasPage extends ConsumerWidget {
  const KategoriKasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const SizedBox.shrink();
    final daftar = ref.watch(kategoriKasProvider);
    final repo = ref.read(keuanganRepositoryProvider);

    Future<void> jalankan(Future<void> Function() aksi, String pesan) async {
      try {
        await aksi();
        ref.invalidate(kategoriKasProvider);
        if (context.mounted) showPesan(context, pesan);
      } on ApiException catch (e) {
        if (context.mounted) showPesan(context, e.message, error: true);
      }
    }

    Future<void> tambah(String tipe) async {
      final nama = await mintaTeks(
        context,
        judul: tipe == 'keluar' ? 'Kategori pengeluaran baru' : 'Kategori pemasukan baru',
        label: 'Nama kategori',
        hint: tipe == 'keluar' ? 'contoh: Transportasi' : 'contoh: Sumbangan alumni',
      );
      if (nama != null) await jalankan(() => repo.simpanKategoriKas(nama: nama, tipe: tipe), 'Kategori ditambahkan.');
    }

    Future<void> kelola(KategoriKas k) async {
      final aksi = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
          child: Wrap(children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Ubah nama'),
              onTap: () => Navigator.pop(context, 'ubah'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.merah),
              title: const Text('Hapus kategori', style: TextStyle(color: AppColors.merah)),
              onTap: () => Navigator.pop(context, 'hapus'),
            ),
          ]),
        ),
      );
      if (aksi == null || !context.mounted) return;

      if (aksi == 'ubah') {
        final nama = await mintaTeks(context, judul: 'Ubah kategori', label: 'Nama kategori', nilaiAwal: k.nama);
        if (nama != null) await jalankan(() => repo.simpanKategoriKas(id: k.id, nama: nama), 'Kategori diperbarui.');
      } else {
        final ok = await konfirmasi(
          context,
          judul: 'Hapus ${k.nama}?',
          isi: 'Kategori yang sudah dipakai di transaksi kas tidak dapat dihapus.',
          ya: 'Hapus',
          bahaya: true,
        );
        if (ok) await jalankan(() => repo.hapusKategoriKas(k.id), 'Kategori dihapus.');
      }
    }

    Widget grup(String judul, List<KategoriKas> items, bool masuk) => SectionCard(
          title: judul,
          trailing: user.bisaKelolaKeuangan
              ? IconButton(
                  tooltip: 'Tambah kategori',
                  onPressed: () => tambah(masuk ? 'masuk' : 'keluar'),
                  icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.hijau),
                )
              : null,
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Column(
            children: [
              for (final k in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(masuk ? Icons.south_west_rounded : Icons.north_east_rounded,
                      color: masuk ? AppColors.hijau : AppColors.merah),
                  title: Text(k.nama),
                  subtitle: k.sistem ? const Text('Otomatis dari pembayaran santri') : null,
                  trailing: k.sistem || !user.bisaKelolaKeuangan ? null : const Icon(Icons.more_vert_rounded, size: 20),
                  onTap: k.sistem || !user.bisaKelolaKeuangan ? null : () => kelola(k),
                ),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Kategori Kas')),
      body: daftar.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(kategoriKasProvider)),
        data: (items) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            grup('Pengeluaran', items.where((k) => k.tipe == 'keluar').toList(), false),
            const SizedBox(height: 16),
            grup('Pemasukan', items.where((k) => k.tipe == 'masuk').toList(), true),
          ],
        ),
      ),
    );
  }
}
