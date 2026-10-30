import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Buku Saku Santri. Isinya belum tersedia, sementara menampilkan keterangan segera rilis.
class BukuSakuPage extends StatelessWidget {
  const BukuSakuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Buku Saku Santri')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(color: AppColors.hijauMuda, borderRadius: BorderRadius.circular(28)),
                child: const Icon(Icons.menu_book_rounded, size: 48, color: AppColors.hijau),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: AppColors.emasMuda, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  'Segera hadir',
                  style: text.labelMedium?.copyWith(color: const Color(0xFF8A6D00), fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Buku Saku Akan Segera Rilis',
                textAlign: TextAlign.center,
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Buku Saku Santri sedang disiapkan dan akan tersedia di aplikasi ini dalam waktu dekat.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: AppColors.teks2, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
