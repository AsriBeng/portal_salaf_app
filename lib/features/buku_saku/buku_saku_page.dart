import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import 'waktu_sholat_page.dart';

/// Buku Saku Santri: kumpulan menu ibadah harian. Isi lainnya menyusul.
class BukuSakuPage extends StatelessWidget {
  const BukuSakuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Buku Saku Santri')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const HitungMundurSholat(),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _MenuBesar(
                    icon: Icons.menu_book_rounded,
                    judul: 'Al-Qur\'an',
                    keterangan: 'Mushaf pojok & terjemah',
                    warna: AppColors.hijau,
                    onTap: () => context.push('/al-quran'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MenuBesar(
                    icon: Icons.access_time_filled_rounded,
                    judul: 'Waktu Sholat',
                    keterangan: 'Jadwal sesuai lokasi',
                    warna: AppColors.biru,
                    onTap: () => context.push('/waktu-sholat'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.emasMuda, borderRadius: BorderRadius.circular(14)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_stories_outlined, size: 20, color: Color(0xFF8A6D00)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Buku Saku Santri akan segera lengkap. Tata tertib, jadwal kegiatan, dan panduan pondok '
                    'akan ditambahkan di halaman ini.',
                    style: text.bodySmall?.copyWith(color: const Color(0xFF6B5500), height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuBesar extends StatelessWidget {
  const _MenuBesar({required this.icon, required this.judul, required this.keterangan, required this.warna, required this.onTap});

  final IconData icon;
  final String judul;
  final String keterangan;
  final Color warna;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: warna.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: warna, size: 28),
              ),
              const SizedBox(height: 14),
              Text(judul, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(keterangan, style: text.bodySmall?.copyWith(color: AppColors.teks2)),
            ],
          ),
        ),
      ),
    );
  }
}
