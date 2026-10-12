import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  Future<void> _keluar(BuildContext context, WidgetRef ref) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari aplikasi?'),
        content: const Text('Anda perlu memasukkan NIS/username dan password lagi untuk masuk.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.merah, minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (yakin == true) await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const SizedBox.shrink();

    final text = Theme.of(context).textTheme;
    final santri = user.santri;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  UserAvatar(
                    inisial: user.inisial,
                    fotoUrl: santri?.fotoUrl,
                    headers: ref.read(apiClientProvider).authHeaders,
                    size: 84,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user.name,
                    textAlign: TextAlign.center,
                    style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Pill(label: user.jabatan),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Informasi akun',
            child: Column(
              children: [
                _InfoRow(icon: Icons.badge_outlined, label: user.isSantri ? 'NIS' : 'Username', value: user.username),
                _InfoRow(icon: Icons.shield_outlined, label: 'Peran', value: user.role.label),
                if (user.genderLabel != null) _InfoRow(icon: Icons.wc_rounded, label: 'Bagian', value: user.genderLabel!),
                if (santri?.komplek != null) _InfoRow(icon: Icons.apartment_rounded, label: 'Komplek', value: santri!.komplek!),
                if (santri?.kamar != null) _InfoRow(icon: Icons.meeting_room_outlined, label: 'Kamar', value: santri!.kamar!),
                if (user.phone != null && user.phone!.isNotEmpty) _InfoRow(icon: Icons.phone_outlined, label: 'Telepon', value: user.phone!),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                if (user.isAdmin) ...[
                  _MenuTile(
                    icon: Icons.manage_accounts_outlined,
                    label: 'Kelola pengurus',
                    onTap: () => context.push('/pengurus'),
                  ),
                  const Divider(indent: 64),
                  _MenuTile(
                    icon: Icons.settings_outlined,
                    label: 'Pengaturan pondok',
                    onTap: () => context.push('/pengaturan'),
                  ),
                  const Divider(indent: 64),
                ],
                if (!user.isSantri) ...[
                  _MenuTile(
                    icon: Icons.campaign_outlined,
                    label: 'Pengumuman',
                    onTap: () => context.push('/pengumuman'),
                  ),
                  const Divider(indent: 64),
                ],
                if (user.isSantri) ...[
                  _MenuTile(
                    icon: Icons.assignment_ind_outlined,
                    label: 'Data diri & dokumen',
                    onTap: () => context.push('/data-diri'),
                  ),
                  const Divider(indent: 64),
                ],
                _MenuTile(
                  icon: Icons.lock_reset_rounded,
                  label: 'Ubah password',
                  onTap: () => context.push('/profil/password'),
                ),
                const Divider(indent: 64),
                _MenuTile(
                  icon: Icons.info_outline_rounded,
                  label: 'Tentang aplikasi',
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: AppConfig.appName,
                    applicationVersion: 'Versi 1.0.0',
                    applicationIcon: const AppLogo(size: 56),
                    applicationLegalese: AppConfig.tagline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.merah,
              side: const BorderSide(color: Color(0xFFF3C4C0), width: 1.4),
            ),
            onPressed: () => _keluar(context, ref),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Keluar'),
          ),
          const SizedBox(height: 20),
          Text(
            '${AppConfig.appName} · ${AppConfig.tagline}',
            textAlign: TextAlign.center,
            style: text.labelSmall?.copyWith(color: AppColors.teks2),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.teks2),
          const SizedBox(width: 12),
          Text(label, style: text.bodyMedium?.copyWith(color: AppColors.teks2)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: AppColors.hijauMuda, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 20, color: AppColors.hijau),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.teks2),
    );
  }
}
