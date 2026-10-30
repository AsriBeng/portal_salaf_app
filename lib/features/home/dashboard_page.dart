import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/user.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';
import '../notifikasi/notifikasi_page.dart';
import 'dashboard_provider.dart';
import 'tab_provider.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final dashboard = ref.watch(dashboardProvider);

    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.hijau,
        onRefresh: () => ref.refresh(dashboardProvider.future),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _Header(user: user, data: dashboard.value),
            ),
            ...dashboard.when(
              loading: () => [const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))],
              error: (e, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorView(message: e.toString(), onRetry: () => ref.invalidate(dashboardProvider)),
                ),
              ],
              data: (data) => [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverList.list(
                    children: user.isSantri ? _isiSantri(context, ref, data) : _isiPengurus(context, ref, user, data),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _isiSantri(BuildContext context, WidgetRef ref, Map<String, dynamic> data) {
    void keTab(int tab) => ref.read(tabAktifProvider.notifier).pilih(tab);
    void keTagihan() => keTab(TabSantri.tagihan);

    final tagihan = data['tagihan'] as Map<String, dynamic>;
    final daftar = (tagihan['daftar'] as List).cast<Map<String, dynamic>>();
    final menunggu = data['pembayaran_menunggu'] as int? ?? 0;
    final jumlah = tagihan['jumlah_belum_lunas'] as int? ?? 0;

    return [
      _TagihanSantriCard(total: tagihan['total_belum_lunas'] as num? ?? 0, jumlah: jumlah, menunggu: menunggu, onTap: keTagihan),
      if (daftar.isNotEmpty) ...[
        const SizedBox(height: 16),
        SectionCard(
          title: 'Tagihan belum lunas',
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              for (final t in daftar)
                _TagihanTile(
                  data: t,
                  onTap: () async {
                    await context.push('/tagihan/${t['id']}');
                    ref.invalidate(dashboardProvider);
                  },
                ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 16),
      _MenuPintas(
        items: [
          _ItemMenu(Icons.menu_book_rounded, 'Buku Saku', const Color(0xFF8A6D00), () => context.push('/buku-saku')),
          _ItemMenu(Icons.badge_rounded, 'ID Card', AppColors.hijau, () => keTab(TabSantri.kartu)),
          _ItemMenu(Icons.receipt_long_rounded, 'Tagihan', AppColors.oranye, keTagihan),
          _ItemMenu(Icons.person_rounded, 'Profil', AppColors.biru, () => keTab(TabSantri.profil)),
        ],
      ),
      const SizedBox(height: 16),
      _PengumumanSection(items: (data['pengumuman_terbaru'] as List).cast<Map<String, dynamic>>()),
    ];
  }

  /// Tombol pintas ke tab dan halaman yang boleh dibuka pengurus sesuai perannya.
  List<_ItemMenu> _menuPengurus(BuildContext context, WidgetRef ref, User user) {
    final tabs = urutanTab(user.role);
    _ItemMenu? tab(MenuTab t, IconData icon, String label, Color warna) =>
        tabs.contains(t) ? _ItemMenu(icon, label, warna, () => ref.read(tabAktifProvider.notifier).pilih(tabs.indexOf(t))) : null;

    return [
      ?tab(MenuTab.santri, Icons.groups_rounded, 'Santri', AppColors.hijau),
      ?tab(MenuTab.kamar, Icons.meeting_room_rounded, 'Kamar', AppColors.oranye),
      ?tab(MenuTab.keuangan, Icons.account_balance_wallet_rounded, 'Keuangan', AppColors.biru),
      _ItemMenu(Icons.campaign_rounded, 'Pengumuman', const Color(0xFF6D28D9), () => context.push('/pengumuman')),
      if (user.isAdmin) ...[
        _ItemMenu(Icons.manage_accounts_rounded, 'Pengurus', AppColors.hijau, () => context.push('/pengurus')),
        _ItemMenu(Icons.settings_rounded, 'Pengaturan', AppColors.teks2, () => context.push('/pengaturan')),
      ],
      _ItemMenu(Icons.menu_book_rounded, 'Buku Saku', const Color(0xFF8A6D00), () => context.push('/buku-saku')),
      ?tab(MenuTab.profil, Icons.person_rounded, 'Profil', AppColors.biru),
    ];
  }

  List<Widget> _isiPengurus(BuildContext context, WidgetRef ref, User user, Map<String, dynamic> data) {
    final santri = data['santri'] as Map<String, dynamic>;
    final kamar = data['kamar'] as Map<String, dynamic>?;
    final keuangan = data['keuangan'] as Map<String, dynamic>?;

    return [
      _JudulBagian('Santri'),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 142,
        children: [
          StatTile(icon: Icons.groups_rounded, label: 'Santri aktif', value: angka(santri['aktif'] as num?)),
          if (user.isAdmin) ...[
            StatTile(
              icon: Icons.male_rounded,
              label: 'Putra',
              value: angka(santri['putra'] as num?),
              color: AppColors.biru,
              background: AppColors.biruMuda,
            ),
            StatTile(
              icon: Icons.female_rounded,
              label: 'Putri',
              value: angka(santri['putri'] as num?),
              color: const Color(0xFFBE185D),
              background: const Color(0xFFFCE7F3),
            ),
          ],
          StatTile(
            icon: Icons.bed_outlined,
            label: 'Belum dapat kamar',
            value: angka(santri['tanpa_kamar'] as num?),
            color: AppColors.oranye,
            background: AppColors.oranyeMuda,
          ),
        ],
      ),
      const SizedBox(height: 20),
      _JudulBagian('Menu'),
      _MenuPintas(items: _menuPengurus(context, ref, user)),
      if (kamar != null) ...[const SizedBox(height: 20), _JudulBagian('Kamar'), _KamarCard(data: kamar)],
      if (keuangan != null) ...[
        const SizedBox(height: 20),
        _JudulBagian('Keuangan'),
        _SaldoCard(user: user, saldo: keuangan['saldo_kas'] as Map<String, dynamic>),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 142,
          children: [
            StatTile(
              icon: Icons.hourglass_top_rounded,
              label: 'Menunggu verifikasi',
              value: angka(keuangan['pembayaran_menunggu'] as num?),
              color: AppColors.oranye,
              background: AppColors.oranyeMuda,
            ),
            StatTile(
              icon: Icons.payments_outlined,
              label: 'Diterima bulan ini',
              value: rupiah(keuangan['pembayaran_bulan_ini'] as num?),
            ),
            StatTile(
              icon: Icons.receipt_long_outlined,
              label: 'Total tunggakan',
              value: rupiah(keuangan['total_tunggakan'] as num?),
              caption: '${angka(keuangan['tagihan_belum_lunas'] as num?)} tagihan',
              color: AppColors.merah,
              background: AppColors.merahMuda,
            ),
          ],
        ),
      ],
      const SizedBox(height: 20),
      _PengumumanSection(items: (data['pengumuman_terbaru'] as List).cast<Map<String, dynamic>>()),
    ];
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.user, this.data});

  final User user;
  final Map<String, dynamic>? data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final santri = data?['santri'] as Map<String, dynamic>?;
    final notif = data?['notifikasi_belum_dibaca'] as int? ?? 0;

    final subjudul = user.isSantri
        ? [
            'NIS ${user.username}',
            if (santri?['kamar'] != null) santri!['kamar'],
            if (santri?['komplek'] != null) santri!['komplek'],
          ].join(' · ')
        : user.jabatan;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.gradien,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 16, 20, 24),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                inisial: user.inisial,
                fotoUrl: santri?['foto_url'] as String? ?? user.fotoProfil,
                headers: ref.read(apiClientProvider).authHeaders,
                size: 52,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${salam()},', style: text.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              _NotifButton(jumlah: notif),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.emas.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(user.isSantri ? Icons.school_outlined : Icons.verified_user_outlined, size: 16, color: AppColors.emas),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    subjudul,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
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

class _NotifButton extends ConsumerWidget {
  const _NotifButton({required this.jumlah});

  final int jumlah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Notifikasi',
      style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.14)),
      onPressed: () async {
        await context.push('/notifikasi');
        ref.invalidate(dashboardProvider);
      },
      icon: LencanaNotif(
        jumlahAwal: jumlah,
        child: const Icon(Icons.notifications_none_rounded, color: Colors.white),
      ),
    );
  }
}

class _ItemMenu {
  const _ItemMenu(this.icon, this.label, this.warna, this.onTap);

  final IconData icon;
  final String label;
  final Color warna;
  final VoidCallback onTap;
}

/// Deretan tombol pintas di beranda, 4 per baris.
class _MenuPintas extends StatelessWidget {
  const _MenuPintas({required this.items});

  final List<_ItemMenu> items;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisExtent: 92,
          children: [
            for (final m in items)
              InkWell(
                onTap: m.onTap,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(color: m.warna.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                        child: Icon(m.icon, color: m.warna),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        m.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.2),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _JudulBagian extends StatelessWidget {
  const _JudulBagian(this.judul);

  final String judul;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(judul, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
    );
  }
}

class _KamarCard extends StatelessWidget {
  const _KamarCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final kapasitas = (data['kapasitas'] as num? ?? 0).toInt();
    final terisi = (data['terisi'] as num? ?? 0).toInt();
    final rasio = kapasitas == 0 ? 0.0 : (terisi / kapasitas).clamp(0.0, 1.0);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: angka(terisi),
                        style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(
                        text: ' / ${angka(kapasitas)} tempat terisi',
                        style: text.bodyMedium?.copyWith(color: AppColors.teks2),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                '${(rasio * 100).round()}%',
                style: text.titleMedium?.copyWith(color: AppColors.hijau, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: rasio,
              minHeight: 10,
              backgroundColor: AppColors.hijauMuda,
              color: rasio >= 0.95 ? AppColors.oranye : AppColors.hijau,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${angka(data['jumlah'] as num?)} kamar · ${angka(data['penuh'] as num?)} kamar penuh',
            style: text.bodySmall?.copyWith(color: AppColors.teks2, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SaldoCard extends StatelessWidget {
  const _SaldoCard({required this.user, required this.saldo});

  final User user;
  final Map<String, dynamic> saldo;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final putra = saldo['putra'] as num?;
    final putri = saldo['putri'] as num?;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(colors: [Color(0xFF0F7A45), AppColors.hijauTua]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, color: AppColors.emas, size: 20),
              const SizedBox(width: 8),
              Text(
                user.isAdmin ? 'Saldo kas pondok' : 'Saldo kas ${user.genderLabel?.toLowerCase() ?? ''}',
                style: text.labelLarge?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              rupiah(saldo['total'] as num?),
              style: text.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
          if (putra != null && putri != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SaldoBagian(label: 'Kas putra', nilai: putra),
                ),
                Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.2)),
                const SizedBox(width: 16),
                Expanded(
                  child: _SaldoBagian(label: 'Kas putri', nilai: putri),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SaldoBagian extends StatelessWidget {
  const _SaldoBagian({required this.label, required this.nilai});

  final String label;
  final num nilai;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.labelMedium?.copyWith(color: Colors.white.withValues(alpha: 0.7))),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            rupiah(nilai),
            style: text.titleMedium?.copyWith(color: AppColors.emas, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _TagihanSantriCard extends StatelessWidget {
  const _TagihanSantriCard({required this.total, required this.jumlah, required this.menunggu, required this.onTap});

  final num total;
  final int jumlah;
  final int menunggu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final lunas = jumlah == 0;

    return Material(
      color: lunas ? AppColors.hijauMuda : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: lunas ? const Color(0xFFBFE3CE) : AppColors.garis),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    lunas ? Icons.verified_rounded : Icons.receipt_long_rounded,
                    color: lunas ? AppColors.hijau : AppColors.merah,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    lunas ? 'Semua tagihan lunas' : 'Total tagihan belum lunas',
                    style: text.labelLarge?.copyWith(color: AppColors.teks2, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                lunas ? 'Alhamdulillah' : rupiah(total),
                style: text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: lunas ? AppColors.hijau : AppColors.teks,
                ),
              ),
              if (!lunas) ...[
                const SizedBox(height: 4),
                Text('$jumlah tagihan', style: text.bodySmall?.copyWith(color: AppColors.teks2)),
              ],
              if (menunggu > 0) ...[
                const SizedBox(height: 12),
                Pill(
                  label: '$menunggu pembayaran menunggu verifikasi',
                  color: AppColors.oranye,
                  background: AppColors.oranyeMuda,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    lunas ? 'Lihat riwayat tagihan' : 'Lihat & bayar tagihan',
                    style: text.labelLarge?.copyWith(color: AppColors.hijau, fontWeight: FontWeight.w800),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.hijau, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagihanTile extends StatelessWidget {
  const _TagihanTile({required this.data, required this.onTap});

  final Map<String, dynamic> data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dicicil = data['status'] == 'dicicil';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: dicicil ? AppColors.oranyeMuda : AppColors.merahMuda,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.receipt_outlined, size: 20, color: dicicil ? AppColors.oranye : AppColors.merah),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['judul'] as String, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                  Text(
                    dicicil
                        ? 'Dicicil · jatuh tempo ${tanggal(data['jatuh_tempo'] as String?)}'
                        : 'Jatuh tempo ${tanggal(data['jatuh_tempo'] as String?)}',
                    style: text.bodySmall?.copyWith(color: AppColors.teks2),
                  ),
                ],
              ),
            ),
            Text(rupiah(data['sisa'] as num?), style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
            const Icon(Icons.chevron_right_rounded, color: AppColors.teks2, size: 20),
          ],
        ),
      ),
    );
  }
}

class _PengumumanSection extends StatelessWidget {
  const _PengumumanSection({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return SectionCard(
      title: 'Pengumuman terbaru',
      trailing: TextButton(onPressed: () => context.push('/pengumuman'), child: const Text('Lihat semua')),
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.campaign_outlined, color: AppColors.teks2),
                  const SizedBox(width: 10),
                  Text('Belum ada pengumuman.', style: text.bodyMedium?.copyWith(color: AppColors.teks2)),
                ],
              ),
            )
          : Column(
              children: [
                for (final (i, p) in items.indexed) ...[
                  if (i > 0) const Divider(height: 20),
                  InkWell(
                    onTap: () => context.push('/pengumuman/${p['id']}'),
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: AppColors.emasMuda, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.campaign_rounded, size: 20, color: Color(0xFF8A6D00)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p['judul'] as String, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(
                                p['isi'] as String,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall?.copyWith(color: AppColors.teks2),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tanggalWaktu(p['published_at'] as String?),
                                style: text.labelSmall?.copyWith(color: AppColors.teks2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
