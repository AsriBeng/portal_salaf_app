import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/pengaturan_page.dart';
import '../features/admin/pengurus_pages.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/login_page.dart';
import '../features/home/home_shell.dart';
import '../features/kartu/kartu_page.dart';
import '../features/keuangan/kas_pages.dart';
import '../features/keuangan/laporan_page.dart';
import '../features/keuangan/pembayaran_pages.dart';
import '../features/keuangan/pengaturan_keuangan_pages.dart';
import '../features/keuangan/tagihan_pages.dart';
import '../features/komplek/komplek_pages.dart';
import '../features/notifikasi/notifikasi_page.dart';
import '../features/pengumuman/pengumuman_pages.dart';
import '../features/profile/change_password_page.dart';
import '../features/santri/santri_detail_page.dart';
import '../features/santri/santri_form_page.dart';
import '../features/splash/splash_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Beri tahu router setiap kali status login berubah
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  int id(GoRouterState state) => int.parse(state.pathParameters['id']!);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final lokasi = state.matchedLocation;
      final tujuan = state.uri.queryParameters['dari'];

      // Masih memeriksa sesi, atau gagal terhubung → tetap di splash.
      // Halaman yang dibuka diingat supaya bisa kembali ke sana setelah sesi siap.
      if (auth.isLoading || auth.hasError) {
        if (lokasi == '/splash') return null;
        final dari = state.uri.toString() == '/' || lokasi == '/login' ? null : state.uri.toString();
        return dari == null ? '/splash' : '/splash?dari=${Uri.encodeComponent(dari)}';
      }

      final login = auth.value != null;
      if (!login) return lokasi == '/login' ? null : '/login';
      if (lokasi == '/splash' || lokasi == '/login') return tujuan ?? '/';

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/', builder: (_, s) => HomeShell(tabUrl: int.tryParse(s.uri.queryParameters['tab'] ?? ''))),
      GoRoute(path: '/profil/password', builder: (_, _) => const ChangePasswordPage()),

      // Komplek & kamar
      GoRoute(path: '/komplek/:id', builder: (_, s) => KomplekDetailPage(id: id(s))),
      GoRoute(path: '/kamar/:id', builder: (_, s) => KamarDetailPage(id: id(s))),

      // Santri
      GoRoute(path: '/santri-baru', builder: (_, _) => const SantriFormPage()),
      GoRoute(path: '/data-diri', builder: (_, _) => const SantriDetailPage()),
      GoRoute(path: '/santri/:id', builder: (_, s) => SantriDetailPage(id: id(s))),
      GoRoute(path: '/santri/:id/ubah', builder: (_, s) => SantriFormPage(santriId: id(s))),
      GoRoute(path: '/santri/:id/kartu', builder: (_, s) => KartuPage(santriId: id(s))),

      // Admin
      GoRoute(path: '/pengurus', builder: (_, _) => const PengurusPage()),
      GoRoute(path: '/pengaturan', builder: (_, _) => const PengaturanPage()),

      // Pengumuman & notifikasi
      GoRoute(path: '/notifikasi', builder: (_, _) => const NotifikasiPage()),
      GoRoute(path: '/pengumuman', builder: (_, _) => const PengumumanListPage()),
      GoRoute(path: '/pengumuman-baru', builder: (_, _) => const PengumumanFormPage()),
      GoRoute(path: '/pengumuman/:id', builder: (_, s) => PengumumanDetailPage(id: id(s))),
      GoRoute(path: '/pengumuman/:id/ubah', builder: (_, s) => PengumumanFormPage(id: id(s))),

      // Keuangan
      GoRoute(path: '/tagihan', builder: (_, _) => const TagihanListPage()),
      GoRoute(path: '/tagihan/:id', builder: (_, s) => TagihanDetailPage(id: id(s))),
      GoRoute(
        path: '/tagihan-santri/:id',
        builder: (_, s) => TagihanListPage(santriId: id(s), namaSantri: s.uri.queryParameters['nama']),
      ),
      GoRoute(path: '/tagihan-iuran', builder: (_, _) => const BuatIuranPage()),
      GoRoute(path: '/pembayaran', builder: (_, _) => const PembayaranListPage()),
      GoRoute(path: '/pembayaran/:id', builder: (_, s) => PembayaranDetailPage(id: id(s))),
      GoRoute(path: '/kas', builder: (_, _) => const KasPage()),
      GoRoute(path: '/kas-baru', builder: (_, _) => const KasFormPage()),
      GoRoute(path: '/laporan', builder: (_, _) => const LaporanPage()),
      GoRoute(path: '/jenis-tagihan', builder: (_, _) => const JenisTagihanPage()),
      GoRoute(path: '/kategori-kas', builder: (_, _) => const KategoriKasPage()),
    ],
  );
});
