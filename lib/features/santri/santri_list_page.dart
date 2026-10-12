import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/akses.dart';
import '../../models/santri.dart';
import '../../shared/ui.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';
import '../komplek/komplek_pages.dart';
import 'santri_repository.dart';

/// Daftar santri dengan pencarian, filter, dan muat otomatis saat digulir.
class SantriListPage extends ConsumerStatefulWidget {
  const SantriListPage({super.key});

  @override
  ConsumerState<SantriListPage> createState() => _SantriListPageState();
}

class _SantriListPageState extends ConsumerState<SantriListPage> {
  final _cari = TextEditingController();
  final _scroll = ScrollController();
  Timer? _jeda;

  String _status = 'aktif';
  String? _gender;

  final List<Santri> _items = [];
  int _page = 0;
  int _total = 0;
  bool _adaLagi = true;
  bool _loading = false;
  String? _error;

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
    _jeda?.cancel();
    _cari.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _muat({bool ulang = false}) async {
    if (_loading && !ulang) return;
    if (!ulang && !_adaLagi) return;

    final halaman = ulang ? 1 : _page + 1;
    setState(() {
      _loading = true;
      _error = null;
      if (ulang) {
        _items.clear();
        _adaLagi = true;
      }
    });

    try {
      final hasil = await ref.read(santriRepositoryProvider).daftar(
            page: halaman,
            search: _cari.text.trim(),
            status: _status,
            gender: _gender,
          );
      if (!mounted) return;
      setState(() {
        if (ulang) _items.clear();
        _items.addAll(hasil.items);
        _page = hasil.page;
        _total = hasil.total;
        _adaLagi = hasil.adaLagi;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _cariBerubah(String _) {
    _jeda?.cancel();
    _jeda = Timer(const Duration(milliseconds: 450), () => _muat(ulang: true));
  }

  Future<void> _buka(String path) async {
    await context.push(path);
    if (mounted) _muat(ulang: true);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const SizedBox.shrink();
    final headers = ref.read(apiClientProvider).authHeaders;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Data Santri')),
      floatingActionButton: user.bisaKelolaSantri
          ? FloatingActionButton.extended(
              onPressed: () => _buka('/santri-baru'),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Santri'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _cari,
              onChanged: _cariBerubah,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari nama atau NIS',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _cari.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _cari.clear();
                          _muat(ulang: true);
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final (v, label) in [('aktif', 'Aktif'), ('lulus', 'Lulus'), ('keluar', 'Keluar'), ('semua', 'Semua status')])
                  _Chip(label: label, selected: _status == v, onTap: () {
                    setState(() => _status = v);
                    _muat(ulang: true);
                  }),
                if (user.isAdmin) ...[
                  const SizedBox(width: 4),
                  const VerticalDivider(width: 16, indent: 8, endIndent: 8),
                  for (final (v, label) in [(null, 'Putra & Putri'), ('L', 'Putra'), ('P', 'Putri')])
                    _Chip(label: label, selected: _gender == v, onTap: () {
                      setState(() => _gender = v);
                      _muat(ulang: true);
                    }),
                ],
              ],
            ),
          ),
          if (_total > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${angka(_total)} santri', style: text.labelMedium?.copyWith(color: AppColors.teks2)),
              ),
            ),
          Expanded(child: _isi(headers)),
        ],
      ),
    );
  }

  Widget _isi(Map<String, String> headers) {
    if (_items.isEmpty && _loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty && _error != null) return ErrorView(message: _error!, onRetry: () => _muat(ulang: true));
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _muat(ulang: true),
        child: ListView(children: [
          const SizedBox(height: 60),
          EmptyView(
            icon: Icons.groups_rounded,
            judul: _cari.text.isEmpty ? 'Belum ada santri' : 'Santri tidak ditemukan',
            isi: _cari.text.isEmpty ? null : 'Coba kata kunci lain.',
          ),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _muat(ulang: true),
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: _items.length + (_adaLagi ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))),
            );
          }
          return SantriTile(santri: _items[i], headers: headers, onTap: () => _buka('/santri/${_items[i].id}'));
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: AppColors.hijau,
        labelStyle: TextStyle(color: selected ? Colors.white : AppColors.teks, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Baris santri: foto, nama, NIS, kamar.
class SantriTile extends StatelessWidget {
  const SantriTile({super.key, required this.santri, required this.headers, required this.onTap});

  final Santri santri;
  final Map<String, String> headers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final kamar = santri.kamar;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              UserAvatar(inisial: santri.inisial, fotoUrl: santri.fotoUrl, headers: headers, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      santri.namaLengkap,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        'NIS ${santri.nis}',
                        if (kamar != null) kamar.labelLengkap else if (santri.status == StatusSantri.aktif) 'Belum ada kamar',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: AppColors.teks2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GenderPill(santri.jenisKelamin),
                  if (santri.status != StatusSantri.aktif) ...[
                    const SizedBox(height: 4),
                    Pill(label: santri.status.label, color: AppColors.teks2, background: AppColors.garis),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
