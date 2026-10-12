import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user.dart';
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
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
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

    return switch (role) {
      // Urutan harus sama dengan TabSantri
      Role.santri => [beranda, kartu, tagihanSantri, profil],
      Role.sekretaris => [beranda, santri, kamar, profil],
      Role.bendahara => [beranda, keuangan, santri, profil],
      Role.admin || Role.ketua => [beranda, santri, kamar, keuangan, profil],
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const SizedBox.shrink();

    final tabs = _tabs(user.role);
    final index = ref.watch(tabAktifProvider).clamp(0, tabs.length - 1);

    return Scaffold(
      body: IndexedStack(index: index, children: [for (final t in tabs) t.page]),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE3EBE6))),
        ),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: ref.read(tabAktifProvider.notifier).pilih,
          destinations: [
            for (final t in tabs)
              NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.activeIcon), label: t.label),
          ],
        ),
      ),
    );
  }
}
