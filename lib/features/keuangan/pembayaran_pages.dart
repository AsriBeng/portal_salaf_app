import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/akses.dart';
import '../../models/keuangan.dart';
import '../../shared/paged_list.dart';
import '../../shared/ui.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';
import 'keuangan_repository.dart';
import 'keuangan_widgets.dart';

/// Daftar pembayaran per status. Tab "Menunggu" = antrean verifikasi bendahara.
class PembayaranListPage extends ConsumerStatefulWidget {
  const PembayaranListPage({super.key});

  @override
  ConsumerState<PembayaranListPage> createState() => _PembayaranListPageState();
}

class _PembayaranListPageState extends ConsumerState<PembayaranListPage> with SingleTickerProviderStateMixin {
  static const _status = ['menunggu', 'disetujui', 'ditolak'];
  late final _tab = TabController(length: _status.length, vsync: this);
  int _versi = 0;

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _buka(Pembayaran p) async {
    final berubah = await context.push<bool>('/pembayaran/${p.id}');
    if (berubah == true && mounted) {
      setState(() => _versi++);
      ref.invalidate(jumlahMenungguProvider);
      ref.invalidate(saldoKasProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(keuanganRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembayaran'),
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.hijau,
          indicatorColor: AppColors.hijau,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: const [Tab(text: 'Menunggu'), Tab(text: 'Disetujui'), Tab(text: 'Ditolak')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          for (final status in _status)
            PagedList<Pembayaran>(
              reloadKey: '$status-$_versi',
              muat: (page) => repo.pembayaran(page: page, status: status),
              itemBuilder: (_, p) => PembayaranCard(pembayaran: p, onTap: () => _buka(p)),
              kosong: EmptyView(
                icon: status == 'menunggu' ? Icons.task_alt_rounded : Icons.receipt_long_outlined,
                judul: status == 'menunggu' ? 'Tidak ada yang perlu diverifikasi' : 'Belum ada pembayaran',
                isi: status == 'menunggu' ? 'Bukti transfer dari santri akan muncul di sini.' : null,
              ),
            ),
        ],
      ),
    );
  }
}

/// Detail pembayaran: bukti transfer, info tagihan, tombol setujui / tolak.
class PembayaranDetailPage extends ConsumerStatefulWidget {
  const PembayaranDetailPage({super.key, required this.id});

  final int id;

  @override
  ConsumerState<PembayaranDetailPage> createState() => _PembayaranDetailPageState();
}

class _PembayaranDetailPageState extends ConsumerState<PembayaranDetailPage> {
  bool _proses = false;
  bool _berubah = false;

  Future<void> _setujui(Pembayaran p) async {
    final ok = await konfirmasi(
      context,
      judul: 'Setujui pembayaran?',
      isi: 'Pembayaran ${rupiah(p.nominal)} untuk ${p.tagihan?.judul ?? 'tagihan'} akan dicatat dan masuk ke kas. '
          'Pastikan dana sudah benar-benar diterima.',
      ya: 'Setujui',
    );
    if (!ok) return;
    await _jalankan(() => ref.read(keuanganRepositoryProvider).setujui(p.id), 'Pembayaran disetujui.');
  }

  Future<void> _tolak(Pembayaran p) async {
    final teks = await mintaTeks(
      context,
      judul: 'Tolak pembayaran',
      label: 'Alasan penolakan',
      hint: 'contoh: Bukti tidak terbaca / nominal tidak sesuai',
      helper: 'Alasan ini dikirim ke santri.',
      ya: 'Tolak',
      bahaya: true,
      maxLines: 3,
    );
    if (teks == null) return;
    await _jalankan(() => ref.read(keuanganRepositoryProvider).tolak(p.id, teks), 'Pembayaran ditolak. Santri akan menerima pemberitahuan.');
  }

  Future<void> _jalankan(Future<void> Function() aksi, String pesan) async {
    setState(() => _proses = true);
    try {
      await aksi();
      _berubah = true;
      ref.invalidate(pembayaranDetailProvider(widget.id));
      if (mounted) showPesan(context, pesan);
    } on ApiException catch (e) {
      if (mounted) showPesan(context, e.errors.values.firstOrNull?.first ?? e.message, error: true);
    } finally {
      if (mounted) setState(() => _proses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const SizedBox.shrink();
    final detail = ref.watch(pembayaranDetailProvider(widget.id));
    final headers = ref.read(apiClientProvider).authHeaders;
    final text = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.kembali(_berubah);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Detail Pembayaran')),
        bottomNavigationBar: switch (detail.value) {
          final p? when p.status == StatusPembayaran.menunggu && user.bisaKelolaKeuangan => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _proses ? null : () => _tolak(p),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.merah,
                          side: const BorderSide(color: Color(0xFFF3C4C0), width: 1.4),
                        ),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Tolak'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _proses ? null : () => _setujui(p),
                        icon: _proses
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : const Icon(Icons.check_rounded),
                        label: const Text('Setujui'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          final p? when p.status == StatusPembayaran.ditolak && user.isSantri => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: () => context.pushReplacement('/tagihan/${p.tagihanId}'),
                  icon: const Icon(Icons.upload_rounded),
                  label: const Text('Kirim ulang bukti'),
                ),
              ),
            ),
          _ => null,
        },
        body: detail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(pembayaranDetailProvider(widget.id))),
          data: (p) {
            final t = p.tagihan;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                // Nominal besar
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(gradient: AppColors.gradien, borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Nominal dibayar', style: text.labelLarge?.copyWith(color: Colors.white70)),
                          const Spacer(),
                          StatusPembayaranPill(p.status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(rupiah(p.nominal), style: text.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('${p.metodeLabel} · ${tanggal(p.tanggalBayar)}', style: text.bodyMedium?.copyWith(color: AppColors.emas)),
                    ],
                  ),
                ),
                if (p.status == StatusPembayaran.ditolak && p.alasanTolak != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.merahMuda, borderRadius: BorderRadius.circular(14)),
                    child: Text('Alasan ditolak: ${p.alasanTolak}',
                        style: text.bodyMedium?.copyWith(color: AppColors.merah, fontWeight: FontWeight.w600)),
                  ),
                ],
                const SizedBox(height: 16),
                if (t != null)
                  SectionCard(
                    title: 'Tagihan',
                    trailing: TextButton(onPressed: () => context.push('/tagihan/${t.id}'), child: const Text('Lihat')),
                    child: Column(
                      children: [
                        if (t.santri != null) InfoBaris('Santri', '${t.santri!.namaLengkap} (${t.santri!.nis})'),
                        InfoBaris('Tagihan', t.judul),
                        InfoBaris('Nominal tagihan', rupiah(t.nominal)),
                        InfoBaris('Sudah terbayar', rupiah(t.terbayar)),
                        InfoBaris('Sisa', rupiah(t.sisa), tebal: true, warna: t.sisa > 0 ? AppColors.merah : AppColors.hijau),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Keterangan',
                  child: Column(
                    children: [
                      InfoBaris('Sumber', p.sumberLabel),
                      if (p.pembuat != null) InfoBaris('Dibuat oleh', p.pembuat!),
                      if (p.catatan != null && p.catatan!.isNotEmpty) InfoBaris('Catatan', p.catatan!),
                      if (p.verifikator != null) InfoBaris('Diverifikasi', '${p.verifikator} · ${tanggalWaktu(p.verifiedAt)}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Bukti pembayaran',
                  child: p.buktiUrl == null
                      ? Text('Tidak ada bukti (pembayaran dicatat langsung).', style: text.bodyMedium?.copyWith(color: AppColors.teks2))
                      : GestureDetector(
                          onTap: () => showDialog<void>(
                            context: context,
                            builder: (_) => Dialog(
                              insetPadding: const EdgeInsets.all(12),
                              child: InteractiveViewer(child: Image.network(p.buktiUrl!, headers: headers)),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              p.buktiUrl!,
                              headers: headers,
                              fit: BoxFit.contain,
                              height: 320,
                              loadingBuilder: (_, child, progress) =>
                                  progress == null ? child : const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                              errorBuilder: (_, _, _) => const Text('Gagal memuat bukti.'),
                            ),
                          ),
                        ),
                ),
                if (p.buktiUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Ketuk gambar untuk memperbesar.', textAlign: TextAlign.center, style: text.labelSmall?.copyWith(color: AppColors.teks2)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
