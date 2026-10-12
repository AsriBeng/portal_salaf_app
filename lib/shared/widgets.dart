import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Logo pondok di dalam lingkaran putih dengan cincin emas.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.09),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.emas.withValues(alpha: 0.55), width: size * 0.05),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
    );
  }
}

/// Avatar bulat: foto jika ada, jika tidak inisial nama.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.inisial, this.fotoUrl, this.headers = const {}, this.size = 48});

  final String inisial;
  final String? fotoUrl;
  final Map<String, String> headers;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        inisial,
        style: TextStyle(color: AppColors.hijau, fontWeight: FontWeight.w800, fontSize: size * 0.36),
      ),
    );

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.emasMuda,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: fotoUrl == null
          ? fallback
          : Image.network(fotoUrl!, headers: headers, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
    );
  }
}

/// Kartu putih dengan judul bagian opsional.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.trailing, required this.child, this.padding = const EdgeInsets.all(16)});

  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(title!, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// Kotak angka ringkas dengan ikon berwarna.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color = AppColors.hijau,
    this.background = AppColors.hijauMuda,
    this.caption,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 2),
            Text(label, style: text.bodySmall?.copyWith(color: AppColors.teks2, fontWeight: FontWeight.w600)),
            if (caption != null) ...[
              const SizedBox(height: 2),
              Text(caption!, style: text.labelSmall?.copyWith(color: AppColors.teks2)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tampilan saat gagal memuat data, dengan tombol coba lagi.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: AppColors.merahMuda, shape: BoxShape.circle),
              child: const Icon(Icons.wifi_off_rounded, color: AppColors.merah, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.teks2),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Penanda menu yang akan dikerjakan di tahap berikutnya.
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({super.key, required this.title, required this.icon, required this.description});

  final String title;
  final IconData icon;
  final String description;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(color: AppColors.hijauMuda, shape: BoxShape.circle),
                child: Icon(icon, size: 40, color: AppColors.hijau),
              ),
              const SizedBox(height: 20),
              Text(title, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(description, textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: AppColors.teks2)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.emasMuda, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  'Segera hadir',
                  style: text.labelMedium?.copyWith(color: const Color(0xFF6B5500), fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lencana kecil berwarna (status, peran).
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, this.color = AppColors.hijau, this.background = AppColors.hijauMuda});

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
