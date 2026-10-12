import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../shared/paged_list.dart';
import '../../shared/ui.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';
import '../komplek/komplek_pages.dart';
import 'keuangan_repository.dart';
import 'keuangan_widgets.dart';

class LaporanPage extends ConsumerStatefulWidget {
  const LaporanPage({super.key});

  @override
  ConsumerState<LaporanPage> createState() => _LaporanPageState();
}

class _LaporanPageState extends ConsumerState<LaporanPage> {
  late DateTimeRange _rentang = _bulanIni();
  String _preset = 'bulan_ini';
  String? _gender;

  Future<Map<String, dynamic>>? _rekap;

  static DateTimeRange _bulanIni() {
    final n = DateTime.now();
    return DateTimeRange(start: DateTime(n.year, n.month), end: DateTime(n.year, n.month + 1, 0));
  }

  @override
  void initState() {
    super.initState();
    _muat();
  }

  void _muat() {
    setState(() {
      _rekap = ref.read(keuanganRepositoryProvider).laporanKeuangan(
            dari: isoTanggal(_rentang.start),
            sampai: isoTanggal(_rentang.end),
            gender: _gender,
          );
    });
  }

  void _pilihPreset(String preset) async {
    final n = DateTime.now();
    DateTimeRange? r = switch (preset) {
      'bulan_ini' => _bulanIni(),
      'bulan_lalu' => DateTimeRange(start: DateTime(n.year, n.month - 1), end: DateTime(n.year, n.month, 0)),
      'tahun_ini' => DateTimeRange(start: DateTime(n.year), end: DateTime(n.year, 12, 31)),
      _ => await showDateRangePicker(
          context: context,
          firstDate: DateTime(2015),
          lastDate: DateTime(n.year + 1),
          initialDateRange: _rentang,
          helpText: 'Pilih periode laporan',
        ),
    };
    if (r == null) return;
    _preset = preset;
    _rentang = r;
    _muat();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const SizedBox.shrink();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Laporan Keuangan'),
          bottom: const TabBar(
            labelColor: AppColors.hijau,
            indicatorColor: AppColors.hijau,
            labelStyle: TextStyle(fontWeight: FontWeight.w700),
            tabs: [Tab(text: 'Rekap'), Tab(text: 'Tunggakan')],
          ),
        ),
        body: TabBarView(
          children: [
            _rekapView(user.isAdmin),
            _Tunggakan(admin: user.isAdmin),
          ],
        ),
      ),
    );
  }

  Widget _rekapView(bool admin) {
    final text = Theme.of(context).textTheme;
    final fmt = DateFormat('d MMM yyyy', 'id_ID');

    Widget chip(String label, bool aktif, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label),
            selected: aktif,
            showCheckmark: false,
            selectedColor: AppColors.hijau,
            labelStyle: TextStyle(color: aktif ? Colors.white : AppColors.teks, fontWeight: FontWeight.w600),
            onSelected: (_) => onTap(),
          ),
        );

    return RefreshIndicator(
      onRefresh: () async => _muat(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              chip('Bulan ini', _preset == 'bulan_ini', () => _pilihPreset('bulan_ini')),
              chip('Bulan lalu', _preset == 'bulan_lalu', () => _pilihPreset('bulan_lalu')),
              chip('Tahun ini', _preset == 'tahun_ini', () => _pilihPreset('tahun_ini')),
              chip('Pilih tanggal', _preset == 'custom', () => _pilihPreset('custom')),
            ]),
          ),
          if (admin) ...[
            const SizedBox(height: 8),
            Row(children: [
              chip('Putra & putri', _gender == null, () {
                _gender = null;
                _muat();
              }),
              chip('Putra', _gender == 'L', () {
                _gender = 'L';
                _muat();
              }),
              chip('Putri', _gender == 'P', () {
                _gender = 'P';
                _muat();
              }),
            ]),
          ],
          const SizedBox(height: 12),
          Text('${fmt.format(_rentang.start)} – ${fmt.format(_rentang.end)}', style: text.labelLarge?.copyWith(color: AppColors.teks2)),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, dynamic>>(
            future: _rekap,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
              }
              if (snap.hasError) return ErrorView(message: '${snap.error}', onRetry: _muat);

              final d = snap.data!;
              final tagihan = d['tagihan_terbit'] as Map<String, dynamic>;
              final bayar = d['pembayaran_diterima'] as Map<String, dynamic>;
              final kas = d['kas'] as Map<String, dynamic>;
              final kategori = (kas['per_kategori'] as List).cast<Map<String, dynamic>>();
              final selisih = kas['selisih'] as num;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 128,
                    children: [
                      StatTile(icon: Icons.south_west_rounded, label: 'Kas masuk', value: rupiah(kas['masuk'] as num)),
                      StatTile(
                        icon: Icons.north_east_rounded,
                        label: 'Kas keluar',
                        value: rupiah(kas['keluar'] as num),
                        color: AppColors.merah,
                        background: AppColors.merahMuda,
                      ),
                      StatTile(
                        icon: Icons.payments_outlined,
                        label: 'Pembayaran diterima',
                        value: rupiah(bayar['total'] as num),
                        caption: '${angka(bayar['jumlah'] as num)} transaksi',
                        color: AppColors.biru,
                        background: AppColors.biruMuda,
                      ),
                      StatTile(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Saldo saat ini',
                        value: rupiah(kas['saldo_saat_ini'] as num),
                        color: const Color(0xFF8A6D00),
                        background: AppColors.emasMuda,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    child: Row(
                      children: [
                        Expanded(child: Text('Selisih masuk − keluar', style: text.bodyMedium?.copyWith(color: AppColors.teks2))),
                        Text(
                          '${selisih < 0 ? '−' : '+'}${rupiah(selisih.abs())}',
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: selisih < 0 ? AppColors.merah : AppColors.hijau,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Tagihan terbit di periode ini',
                    child: Column(children: [
                      InfoBaris('Jumlah tagihan', angka(tagihan['jumlah'] as num)),
                      InfoBaris('Total nominal', rupiah(tagihan['total'] as num)),
                      InfoBaris('Sudah dibayar', rupiah(tagihan['terbayar'] as num), warna: AppColors.hijau),
                      InfoBaris('Belum dibayar', rupiah(tagihan['sisa'] as num), tebal: true, warna: AppColors.merah),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Kas per kategori',
                    child: kategori.isEmpty
                        ? Text('Belum ada transaksi di periode ini.', style: text.bodyMedium?.copyWith(color: AppColors.teks2))
                        : Column(children: [
                            for (final k in kategori)
                              InfoBaris(
                                k['kategori'] as String,
                                '${k['tipe'] == 'masuk' ? '+' : '−'}${rupiah(k['total'] as num)}',
                                warna: k['tipe'] == 'masuk' ? AppColors.hijau : AppColors.merah,
                              ),
                          ]),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Tunggakan extends ConsumerStatefulWidget {
  const _Tunggakan({required this.admin});

  final bool admin;

  @override
  ConsumerState<_Tunggakan> createState() => _TunggakanState();
}

class _TunggakanState extends ConsumerState<_Tunggakan> {
  final _cari = TextEditingController();
  String _kata = '';

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(keuanganRepositoryProvider);
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _cari,
            textInputAction: TextInputAction.search,
            onSubmitted: (v) => setState(() => _kata = v.trim()),
            decoration: const InputDecoration(hintText: 'Cari nama atau NIS', prefixIcon: Icon(Icons.search_rounded)),
          ),
        ),
        Expanded(
          child: PagedList<Map<String, dynamic>>(
            reloadKey: _kata,
            muat: (page) => repo.tunggakan(page: page, search: _kata),
            itemBuilder: (_, s) => Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                onTap: () => context.push(
                  '/tagihan-santri/${s['id']}?nama=${Uri.encodeComponent(s['nama_lengkap'] as String)}',
                ),
                title: Text(s['nama_lengkap'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('NIS ${s['nis']} · ${s['jumlah_tagihan']} tagihan'),
                leading: GenderPill(s['jenis_kelamin'] as String),
                trailing: Text(
                  rupiah(s['total_tunggakan'] as num),
                  style: text.titleSmall?.copyWith(color: AppColors.merah, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            kosong: const EmptyView(
              icon: Icons.verified_rounded,
              judul: 'Tidak ada tunggakan',
              isi: 'Semua santri sudah melunasi tagihannya.',
            ),
            separator: 8,
          ),
        ),
      ],
    );
  }
}
