import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../models/user.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';
import '../kartu/kartu_page.dart';
import '../keuangan/keuangan_page.dart';
import '../keuangan/tagihan_santri_page.dart';
import '../komplek/komplek_pages.dart';
import '../profile/profile_page.dart';
import '../santri/santri_list_page.dart';
import 'dashboard_page.dart';
import 'tab_provider.dart';

class _Tab {
  const _Tab(this.label, this.icon, this.activeIcon, this.page);

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget page;
}

/// Menu bawah, isinya menyesuaikan peran pengguna.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, this.tabUrl});

  /// Versi web: tab dari alamat (/app/?tab=2), supaya tombol kembali browser berpindah antar tab.
  final int? tabUrl;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  @override
  void initState() {
    super.initState();
    // Dibuka langsung / di-refresh dengan ?tab=N
    final dariUrl = widget.tabUrl;
    if (kIsWeb && dariUrl != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(tabAktifProvider.notifier).pilih(dariUrl);
      });
    }
  }

  @override
  void didUpdateWidget(HomeShell old) {
    super.didUpdateWidget(old);
    // Alamat berubah karena tombol kembali/maju browser: ikuti tabnya
    final dariUrl = widget.tabUrl ?? 0;
    if (kIsWeb && dariUrl != (old.tabUrl ?? 0) && dariUrl != ref.read(tabAktifProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(tabAktifProvider.notifier).pilih(dariUrl);
      });
    }
  }

  List<_Tab> _tabs(Role role) {
    const beranda = _Tab('Beranda', Icons.home_outlined, Icons.home_rounded, DashboardPage());
    const profil = _Tab('Profil', Icons.person_outline_rounded, Icons.person_rounded, ProfilePage());
    const santri = _Tab('Santri', Icons.groups_outlined, Icons.groups_rounded, SantriListPage());
    const kamar = _Tab('Kamar', Icons.meeting_room_outlined, Icons.meeting_room_rounded, KomplekListPage());
    const kartu = _Tab('Kartu', Icons.badge_outlined, Icons.badge_rounded, KartuPage());

    const keuangan = _Tab(
      'Keuangan',
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet_rounded,
      KeuanganPage(),
    );
    const tagihanSantri = _Tab('Tagihan', Icons.receipt_long_outlined, Icons.receipt_long_rounded, TagihanSantriPage());

    return [
      for (final t in urutanTab(role))
        switch (t) {
          MenuTab.beranda => beranda,
          MenuTab.santri => santri,
          MenuTab.kamar => kamar,
          MenuTab.keuangan => keuangan,
          MenuTab.kartu => kartu,
          MenuTab.tagihan => tagihanSantri,
          MenuTab.profil => profil,
        },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const SizedBox.shrink();

    final tabs = _tabs(user.role);
    final index = ref.watch(tabAktifProvider).clamp(0, tabs.length - 1);
    final tab = ref.read(tabAktifProvider.notifier);

    // Versi web: setiap pindah tab dicatat di riwayat browser (alamat ?tab=N)
    if (kIsWeb) {
      ref.listen(tabAktifProvider, (_, baru) {
        if (baru != (widget.tabUrl ?? 0)) context.go(baru == 0 ? '/' : '/?tab=$baru');
      });
    }

    // Tombol kembali di HP: pindah ke tab sebelumnya, baru keluar aplikasi dari Beranda
    return PopScope(
      canPop: !tab.bisaKembali,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) tab.kembali();
      },
      child: LayoutBuilder(
        builder: (context, ukuran) {
          final halaman = IndexedStack(index: index, children: [for (final t in tabs) t.page]);

          // Layar lebar (laptop / tablet mendatar): menu di samping, isi dibatasi lebarnya
          if (ukuran.maxWidth >= _lebarMenuSamping) {
            return Scaffold(
              body: Row(
                children: [
                  _MenuSamping(tabs: tabs, index: index, onPilih: tab.pilih),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1080), child: halaman),
                    ),
                  ),
                ],
              ),
            );
          }

          return Scaffold(
            body: halaman,
            bottomNavigationBar: DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE3EBE6))),
              ),
              child: NavigationBar(
                selectedIndex: index,
                onDestinationSelected: tab.pilih,
                destinations: [
                  for (final t in tabs)
                    NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.activeIcon), label: t.label),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Lebar layar minimal untuk memakai menu samping.
const _lebarMenuSamping = 900.0;

/// Menu samping untuk layar lebar (versi web di laptop / tablet).
class _MenuSamping extends StatelessWidget {
  const _MenuSamping({required this.tabs, required this.index, required this.onPilih});

  final List<_Tab> tabs;
  final int index;
  final ValueChanged<int> onPilih;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      width: 248,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.garis)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: [
                  const AppLogo(size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppConfig.appName, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: AppColors.hijauTua)),
                        Text('Portal Santri', style: text.labelSmall?.copyWith(color: AppColors.teks2)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 12),
            for (final (i, t) in tabs.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: _ItemMenu(tab: t, aktif: i == index, onTap: () => onPilih(i)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ItemMenu extends StatelessWidget {
  const _ItemMenu({required this.tab, required this.aktif, required this.onTap});

  final _Tab tab;
  final bool aktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final warna = aktif ? AppColors.hijau : AppColors.teks2;

    return Material(
      color: aktif ? AppColors.hijauMuda : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(aktif ? tab.activeIcon : tab.icon, color: warna, size: 22),
              const SizedBox(width: 14),
              Text(
                tab.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: aktif ? AppColors.hijau : AppColors.teks,
                      fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
