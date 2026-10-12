import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';

/// Layar pembuka: tampil saat aplikasi memeriksa sesi login.
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.gradien),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              const AppLogo(size: 128),
              const SizedBox(height: 28),
              Text(
                AppConfig.appName,
                style: text.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.3),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  AppConfig.tagline,
                  textAlign: TextAlign.center,
                  style: text.titleSmall?.copyWith(color: AppColors.emas, fontWeight: FontWeight.w600, height: 1.4),
                ),
              ),
              const Spacer(flex: 2),
              if (auth.hasError)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(
                        auth.error.toString(),
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => ref.invalidate(authControllerProvider),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.emas,
                          foregroundColor: AppColors.hijauTua,
                          minimumSize: const Size(180, 48),
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.emas),
                ),
              const SizedBox(height: 48),
              Text(
                'Tambakberas Barat · Jombang',
                style: text.labelMedium?.copyWith(color: Colors.white.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
