import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/pengumuman.dart';
import '../../shared/ui.dart';
import '../../shared/widgets.dart';
import '../home/dashboard_provider.dart';
import '../pengumuman/pengumuman_repository.dart';

/// Daftar notifikasi pengguna. Mengetuk notifikasi menandainya dibaca dan membuka halaman terkait.
class NotifikasiPage extends ConsumerStatefulWidget {
  const NotifikasiPage({super.key});

  @override
  ConsumerState<NotifikasiPage> createState() => _NotifikasiPageState();
}

class _NotifikasiPageState extends ConsumerState<NotifikasiPage> {
  final _scroll = ScrollController();
  final List<Notifikasi> _items = [];
  int _page = 0;
  bool _adaLagi = true;
  bool _loading = false;
  String? _error;
  int _belumDibaca = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _muat();
    });
    _muat(ulang: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _muat({bool ulang = false}) async {
    if (_loading || (!ulang && !_adaLagi)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final hasil = await ref.read(pengumumanRepositoryProvider).notifikasi(page: ulang ? 1 : _page + 1);
      if (!mounted) return;
      setState(() {
        if (ulang) _items.clear();
        _items.addAll(hasil.halaman.items);
        _page = hasil.halaman.page;
        _adaLagi = hasil.halaman.adaLagi;
        _belumDibaca = hasil.belumDibaca;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _segarkanLencana() {
    ref.invalidate(notifBelumDibacaProvider);
    ref.invalidate(dashboardProvider);
  }

  Future<void> _ketuk(int i) async {
    final n = _items[i];
    if (!n.dibaca) {
      setState(() {
        _items[i] = n.tandaiDibaca();
        _belumDibaca = (_belumDibaca - 1).clamp(0, _belumDibaca);
      });
      try {
        await ref.read(pengumumanRepositoryProvider).tandaiDibaca(n.id);
        _segarkanLencana();
      } on ApiException {
        // Tidak masalah jika gagal; akan tersinkron saat dimuat ulang
      }
    }
    if (n.tujuan != null && mounted) await context.push(n.tujuan!);
  }

  Future<void> _bacaSemua() async {
    try {
      await ref.read(pengumumanRepositoryProvider).tandaiSemuaDibaca();
      setState(() {
        for (var i = 0; i < _items.length; i++) {
          _items[i] = _items[i].tandaiDibaca();
        }
        _belumDibaca = 0;
      });
      _segarkanLencana();
    } on ApiException catch (e) {
      if (mounted) showPesan(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          if (_belumDibaca > 0)
            TextButton.icon(onPressed: _bacaSemua, icon: const Icon(Icons.done_all_rounded), label: const Text('Baca semua')),
        ],
      ),
      body: _isi(),
    );
  }

  Widget _isi() {
    if (_items.isEmpty && _loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty && _error != null) return ErrorView(message: _error!, onRetry: () => _muat(ulang: true));

    return RefreshIndicator(
      onRefresh: () => _muat(ulang: true),
      child: _items.isEmpty
          ? ListView(children: const [
              SizedBox(height: 80),
              EmptyView(
                icon: Icons.notifications_none_rounded,
                judul: 'Belum ada notifikasi',
                isi: 'Pengumuman, tagihan baru, dan status pembayaran akan muncul di sini.',
              ),
            ])
          : ListView.separated(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              itemCount: _items.length + (_adaLagi ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                if (i >= _items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))),
                  );
                }
                return NotifikasiTile(notifikasi: _items[i], onTap: () => _ketuk(i));
              },
            ),
    );
  }
}

class NotifikasiTile extends StatelessWidget {
  const NotifikasiTile({super.key, required this.notifikasi, required this.onTap});

  final Notifikasi notifikasi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final n = notifikasi;
    final (ikon, warna, latar) = switch (n.tipe) {
      'pengumuman' => (Icons.campaign_rounded, const Color(0xFF8A6D00), AppColors.emasMuda),
      'tagihan' => (Icons.receipt_long_rounded, AppColors.merah, AppColors.merahMuda),
      'pembayaran' when n.judul.contains('ditolak') => (Icons.cancel_rounded, AppColors.merah, AppColors.merahMuda),
      'pembayaran' => (Icons.check_circle_rounded, AppColors.hijau, AppColors.hijauMuda),
      _ => (Icons.notifications_rounded, AppColors.hijau, AppColors.hijauMuda),
    };

    return Material(
      color: n.dibaca ? Colors.white : const Color(0xFFF1FAF5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: n.dibaca ? AppColors.garis : const Color(0xFFBFE3CE)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: latar, borderRadius: BorderRadius.circular(12)),
                child: Icon(ikon, color: warna, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.judul,
                            style: text.titleSmall?.copyWith(fontWeight: n.dibaca ? FontWeight.w600 : FontWeight.w800),
                          ),
                        ),
                        if (!n.dibaca)
                          Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(color: AppColors.hijau, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(n.isi, style: text.bodySmall?.copyWith(color: AppColors.teks2, height: 1.4)),
                    const SizedBox(height: 6),
                    Text(tanggalWaktu(n.createdAt), style: text.labelSmall?.copyWith(color: AppColors.teks2)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lencana jumlah notifikasi belum dibaca (dipakai juga di tombol lonceng).
class LencanaNotif extends ConsumerWidget {
  const LencanaNotif({super.key, required this.child, this.jumlahAwal = 0});

  final Widget child;
  final int jumlahAwal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jumlah = ref.watch(notifBelumDibacaProvider).value ?? jumlahAwal;
    return Badge(
      isLabelVisible: jumlah > 0,
      label: Text(jumlah > 99 ? '99+' : '$jumlah'),
      backgroundColor: AppColors.emas,
      textColor: AppColors.hijauTua,
      child: child,
    );
  }
}
