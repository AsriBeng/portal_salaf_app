import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/akses.dart';
import '../auth/auth_controller.dart';
import 'kas_pages.dart';
import 'keuangan_repository.dart';
import 'tagihan_pages.dart';

/// Tab Keuangan: saldo kas dan menu ke semua fitur keuangan.
class KeuanganPage extends ConsumerWidget {
  const KeuanganPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const SizedBox.shrink();
    final menunggu = ref.watch(jumlahMenungguProvider).value ?? 0;
    final text = Theme.of(context).textTheme;

    Future<void> buka(String path) async {
      await context.push(path);
      ref.invalidate(saldoKasProvider);
      ref.invalidate(jumlahMenungguProvider);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Keuangan')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(saldoKasProvider);
          ref.invalidate(jumlahMenungguProvider);
          await ref.read(saldoKasProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            const SaldoKasCard(),
            const SizedBox(height: 16),

            // Antrean verifikasi, paling menonjol untuk bendahara
            Material(
              color: menunggu > 0 ? AppColors.oranyeMuda : Colors.white,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => buka('/pembayaran'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: menunggu > 0 ? const Color(0xFFF5C99B) : AppColors.garis),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: menunggu > 0 ? AppColors.oranye : AppColors.hijauMuda,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          menunggu > 0 ? Icons.pending_actions_rounded : Icons.task_alt_rounded,
                          color: menunggu > 0 ? Colors.white : AppColors.hijau,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Verifikasi pembayaran', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                            Text(
                              menunggu > 0 ? '$menunggu bukti transfer menunggu dicek' : 'Tidak ada yang menunggu',
                              style: text.bodySmall?.copyWith(
                                color: menunggu > 0 ? AppColors.oranye : AppColors.teks2,
                                fontWeight: menunggu > 0 ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.teks2),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text('Menu', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 104,
              children: [
                _Menu(icon: Icons.receipt_long_rounded, label: 'Tagihan', onTap: () => buka('/tagihan')),
                _Menu(icon: Icons.account_balance_wallet_rounded, label: 'Kas', onTap: () => buka('/kas')),
                _Menu(icon: Icons.bar_chart_rounded, label: 'Laporan', onTap: () => buka('/laporan')),
                if (user.bisaKelolaKeuangan) ...[
                  _Menu(icon: Icons.post_add_rounded, label: 'Buat iuran', warna: AppColors.biru, onTap: () => buka('/tagihan-iuran')),
                  _Menu(
                    icon: Icons.event_repeat_rounded,
                    label: 'Buat SPP',
                    warna: AppColors.biru,
                    onTap: () => bukaGenerateSpp(context, ref),
                  ),
                ],
                _Menu(icon: Icons.category_rounded, label: 'Jenis tagihan', warna: const Color(0xFF8A6D00), onTap: () => buka('/jenis-tagihan')),
                _Menu(icon: Icons.label_rounded, label: 'Kategori kas', warna: const Color(0xFF8A6D00), onTap: () => buka('/kategori-kas')),
              ],
            ),
            if (!user.bisaKelolaKeuangan) ...[
              const SizedBox(height: 20),
              Text(
                'Anda dapat melihat seluruh data keuangan. Pencatatan dan verifikasi dilakukan oleh bendahara.',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: AppColors.teks2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.icon, required this.label, required this.onTap, this.warna = AppColors.hijau});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: warna.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: warna),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
