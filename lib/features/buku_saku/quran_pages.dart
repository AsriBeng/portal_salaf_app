import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../core/theme.dart';
import '../../shared/widgets.dart';
import 'quran_data.dart';

// ---------------------------------------------------------------------------
// Daftar surat & juz
// ---------------------------------------------------------------------------

class AlQuranPage extends ConsumerStatefulWidget {
  const AlQuranPage({super.key});

  @override
  ConsumerState<AlQuranPage> createState() => _AlQuranPageState();
}

class _AlQuranPageState extends ConsumerState<AlQuranPage> {
  ModeQuran? _mode;
  String _cari = '';

  void _buka(QuranData q, ModeQuran mode, int indeks, {int? juz}) {
    final a = q.ayat(indeks);
    if (mode == ModeQuran.mushaf) {
      context.push('/al-quran/mushaf/${q.halaman(indeks)}');
    } else if (juz != null) {
      context.push('/al-quran/terjemah/juz/$juz');
    } else {
      context.push('/al-quran/terjemah/surat/${a.surat}?ayat=${a.ayat}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final quran = ref.watch(quranProvider);
    final pengaturan = ref.watch(pengaturanQuranProvider).value;
    final mode = _mode ?? pengaturan?.modeTerakhir ?? ModeQuran.mushaf;
    final text = Theme.of(context).textTheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: const Text('Al-Qur\'an')),
        body: quran.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(quranProvider)),
          data: (q) {
            final terakhir = mode == ModeQuran.mushaf ? pengaturan?.mushaf : pengaturan?.terjemah;
            final surat = q.surat.where((s) => _cari.isEmpty || '${s.nomor} ${s.latin} ${s.arti}'.toLowerCase().contains(_cari)).toList();

            return NestedScrollView(
              headerSliverBuilder: (context, _) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedButton<ModeQuran>(
                          segments: const [
                            ButtonSegment(value: ModeQuran.mushaf, icon: Icon(Icons.auto_stories_rounded), label: Text('Hafalan')),
                            ButtonSegment(value: ModeQuran.terjemah, icon: Icon(Icons.translate_rounded), label: Text('Terjemah')),
                          ],
                          selected: {mode},
                          onSelectionChanged: (s) => setState(() => _mode = s.first),
                        ),
                        if (terakhir != null) ...[
                          const SizedBox(height: 12),
                          _Lanjutkan(quran: q, posisi: terakhir, onTap: () => _buka(q, mode, terakhir.indeks)),
                        ],
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(pinned: true, delegate: _TabHeader()),
              ],
              body: TabBarView(
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      TextField(
                        decoration: const InputDecoration(hintText: 'Cari surat', prefixIcon: Icon(Icons.search_rounded), isDense: true),
                        onChanged: (v) => setState(() => _cari = v.trim().toLowerCase()),
                      ),
                      const SizedBox(height: 8),
                      for (final s in surat)
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          leading: _Nomor(s.nomor),
                          title: Text(s.latin, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${s.arti} · ${s.jumlahAyat} ayat'),
                          trailing: Text(
                            s.nama,
                            style: const TextStyle(fontFamily: fontQuran, fontSize: 22, color: AppColors.hijauTua),
                          ),
                          onTap: () => _buka(q, mode, q.indeks(s.nomor, 1)),
                        ),
                      _Sumber(text: text),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      for (var juz = 1; juz <= 30; juz++)
                        Builder(
                          builder: (context) {
                            final awal = q.ayat(q.rentangJuz(juz).$1);
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                              leading: _Nomor(juz),
                              title: Text('Juz $juz', style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                'Mulai ${q.surat[awal.surat - 1].latin} ayat ${awal.ayat} · halaman ${q.halaman(awal.indeks)}',
                              ),
                              onTap: () => _buka(q, mode, awal.indeks, juz: juz),
                            );
                          },
                        ),
                      _Sumber(text: text),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TabHeader extends SliverPersistentHeaderDelegate {
  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => ColoredBox(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: const TabBar(
      tabs: [
        Tab(text: 'Surat'),
        Tab(text: 'Juz'),
      ],
    ),
  );

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}

class _Lanjutkan extends StatelessWidget {
  const _Lanjutkan({required this.quran, required this.posisi, required this.onTap});

  final QuranData quran;
  final PosisiBaca posisi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = quran.ayat(posisi.indeks);
    final text = Theme.of(context).textTheme;
    final keterangan = posisi.mode == ModeQuran.mushaf
        ? 'Halaman ${quran.halaman(a.indeks)} · Juz ${quran.juz(a.indeks)}'
        : '${quran.surat[a.surat - 1].latin} ayat ${a.ayat} · Juz ${quran.juz(a.indeks)}';

    return Material(
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(gradient: AppColors.gradien, borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.bookmark_rounded, color: AppColors.emas),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lanjutkan membaca', style: text.labelMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
                      Text(
                        keterangan,
                        style: text.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Nomor extends StatelessWidget {
  const _Nomor(this.nomor);

  final int nomor;

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: AppColors.hijauMuda, borderRadius: BorderRadius.circular(12)),
    child: Text(
      '$nomor',
      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.hijau),
    ),
  );
}

class _Sumber extends StatelessWidget {
  const _Sumber({required this.text});

  final TextTheme text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Text(
      'Teks Al-Qur\'an & terjemahan: Kemenag RI melalui EQuran.id. Huruf: LPMQ Isep Misbah (Lajnah Pentashihan Mushaf '
      'Al-Qur\'an). Pembagian halaman mushaf: Madinah 604 halaman (Tanzil.net, CC BY 3.0).',
      textAlign: TextAlign.center,
      style: text.labelSmall?.copyWith(color: AppColors.teks2, height: 1.4),
    ),
  );
}

/// Tombol ubah ukuran huruf Arab.
class _UkuranHuruf extends ConsumerWidget {
  const _UkuranHuruf();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ukuran = ref.watch(pengaturanQuranProvider).value?.ukuranHuruf ?? 26;
    final atur = ref.read(pengaturanQuranProvider.notifier);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(tooltip: 'Perkecil huruf', onPressed: () => atur.ubahUkuran(ukuran - 2), icon: const Icon(Icons.text_decrease_rounded)),
        IconButton(tooltip: 'Perbesar huruf', onPressed: () => atur.ubahUkuran(ukuran + 2), icon: const Icon(Icons.text_increase_rounded)),
      ],
    );
  }
}

const _coklat = Color(0xFF8A5A3B);
const _bingkai = Color(0xFF4FB592);

/// Nomor akhir ayat: lingkaran bergaris ganda berisi angka Arab, seperti di mushaf cetak.
class _NomorAyat extends StatelessWidget {
  const _NomorAyat({required this.nomor, required this.ukuran});

  final int nomor;
  final double ukuran;

  @override
  Widget build(BuildContext context) {
    final d = ukuran * 1.25;
    return Container(
      width: d,
      height: d,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _coklat, width: 1.4),
      ),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: _coklat.withValues(alpha: 0.7), width: 1.6),
        ),
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Text(
              angkaArab(nomor),
              style: TextStyle(fontFamily: fontQuran, fontSize: ukuran * 0.5, height: 1.2, color: _coklat, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bingkai judul surat (golongan, nama surat, jumlah ayat) beserta basmalah, di awal surat.
class _KepalaSurat extends StatelessWidget {
  const _KepalaSurat({required this.quran, required this.surat, required this.ukuran});

  final QuranData quran;
  final Surat surat;
  final double ukuran;

  @override
  Widget build(BuildContext context) {
    const keterangan = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.teks);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 6),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F7EF),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _bingkai, width: 1.4),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _bingkai.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(child: Text(surat.golongan, style: keterangan)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFC9A27E), width: 1.4),
                  ),
                  child: Text(
                    'سُوْرَةُ ${surat.nama}',
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontFamily: fontQuran, fontSize: 20, height: 1.6, color: AppColors.teks),
                  ),
                ),
                Expanded(
                  child: Text('${surat.jumlahAyat} Ayat', textAlign: TextAlign.right, style: keterangan),
                ),
              ],
            ),
          ),
        ),
        if (surat.pakaiBasmalah)
          Text(
            quran.basmalah,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(fontFamily: fontQuran, fontSize: ukuran, height: 2.0),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Mushaf hafalan: per halaman, tanpa terjemah
// ---------------------------------------------------------------------------

class MushafPage extends ConsumerStatefulWidget {
  const MushafPage({super.key, required this.halaman});

  final int halaman;

  @override
  ConsumerState<MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends ConsumerState<MushafPage> {
  late final _controller = PageController(initialPage: widget.halaman.clamp(1, QuranData.jumlahHalaman) - 1);
  late int _halaman = widget.halaman.clamp(1, QuranData.jumlahHalaman);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _simpan());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _simpan() {
    final q = ref.read(quranProvider).value;
    if (q != null) ref.read(pengaturanQuranProvider.notifier).simpanPosisi(ModeQuran.mushaf, q.rentangHalaman(_halaman).$1);
  }

  @override
  Widget build(BuildContext context) {
    final q = ref.watch(quranProvider).value;
    final ukuran = ref.watch(pengaturanQuranProvider).value?.ukuranHuruf ?? 26;

    if (q == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final awal = q.ayat(q.rentangHalaman(_halaman).$1);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(q.surat[awal.surat - 1].latin),
            Text(
              'Juz ${q.juz(awal.indeks)} · Halaman $_halaman',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.teks2),
            ),
          ],
        ),
        actions: const [_UkuranHuruf()],
      ),
      // reverse: geser ke kanan untuk halaman berikutnya, seperti membalik mushaf
      body: PageView.builder(
        controller: _controller,
        reverse: true,
        itemCount: QuranData.jumlahHalaman,
        onPageChanged: (i) {
          setState(() => _halaman = i + 1);
          _simpan();
        },
        itemBuilder: (context, i) => _HalamanMushaf(quran: q, halaman: i + 1, ukuran: ukuran),
      ),
    );
  }
}

class _HalamanMushaf extends StatelessWidget {
  const _HalamanMushaf({required this.quran, required this.halaman, required this.ukuran});

  final QuranData quran;
  final int halaman;
  final double ukuran;

  @override
  Widget build(BuildContext context) {
    final (awal, akhir) = quran.rentangHalaman(halaman);
    final gaya = TextStyle(fontFamily: fontQuran, fontSize: ukuran, height: 2.1, color: AppColors.teks);

    // Ayat-ayat digabung per paragraf; judul surat memotong paragraf.
    final isi = <Widget>[];
    var paragraf = <InlineSpan>[];
    void tutupParagraf() {
      if (paragraf.isEmpty) return;
      isi.add(
        Text.rich(
          TextSpan(children: paragraf),
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: gaya,
        ),
      );
      paragraf = [];
    }

    for (var i = awal; i < akhir; i++) {
      final a = quran.ayat(i);
      if (a.ayat == 1) {
        tutupParagraf();
        isi.add(_KepalaSurat(quran: quran, surat: quran.surat[a.surat - 1], ukuran: ukuran));
      }
      paragraf.add(TextSpan(text: quran.arab(a.surat, a.ayat)));
      paragraf.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _NomorAyat(nomor: a.ayat, ukuran: ukuran),
        ),
      );
      paragraf.add(const TextSpan(text: ' '));
    }
    tutupParagraf();

    // Halaman pendek (misalnya Al-Fatihah) diletakkan di tengah layar seperti mushaf cetak.
    return LayoutBuilder(
      builder: (context, ukuranLayar) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: ukuranLayar.maxHeight - 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...isi,
              const SizedBox(height: 12),
              Text(
                '$halaman',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.teks2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Terjemah: per surat atau per juz
// ---------------------------------------------------------------------------

class TerjemahPage extends ConsumerStatefulWidget {
  const TerjemahPage({super.key, this.surat, this.juz, this.ayat});

  /// Salah satu dari [surat] atau [juz] diisi.
  final int? surat;
  final int? juz;

  /// Ayat dalam surat yang langsung dituju.
  final int? ayat;

  @override
  ConsumerState<TerjemahPage> createState() => _TerjemahPageState();
}

class _TerjemahPageState extends ConsumerState<TerjemahPage> {
  final _posisi = ItemPositionsListener.create();
  int? _terlihat;

  @override
  void initState() {
    super.initState();
    _posisi.itemPositions.addListener(_catat);
  }

  @override
  void dispose() {
    _posisi.itemPositions.removeListener(_catat);
    super.dispose();
  }

  (int, int) _rentang(QuranData q) => widget.juz != null ? q.rentangJuz(widget.juz!) : q.rentangSurat(widget.surat!);

  /// Simpan ayat teratas yang terlihat sebagai posisi terakhir dibaca.
  void _catat() {
    final q = ref.read(quranProvider).value;
    final posisi = _posisi.itemPositions.value.where((p) => p.itemTrailingEdge > 0);
    if (q == null || posisi.isEmpty) return;
    final teratas = posisi.reduce((a, b) => a.index < b.index ? a : b).index + _rentang(q).$1;
    if (teratas == _terlihat) return;
    _terlihat = teratas;
    ref.read(pengaturanQuranProvider.notifier).simpanPosisi(ModeQuran.terjemah, teratas);
  }

  @override
  Widget build(BuildContext context) {
    final q = ref.watch(quranProvider).value;
    final terjemah = ref.watch(terjemahProvider);
    final ukuran = ref.watch(pengaturanQuranProvider).value?.ukuranHuruf ?? 26;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.juz != null ? 'Juz ${widget.juz}' : (q == null ? '' : q.surat[widget.surat! - 1].latin)),
        actions: const [_UkuranHuruf()],
      ),
      body: q == null
          ? const Center(child: CircularProgressIndicator())
          : terjemah.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(terjemahProvider)),
              data: (arti) {
                final (awal, akhir) = _rentang(q);
                final tuju = widget.surat != null && widget.ayat != null ? q.indeks(widget.surat!, widget.ayat!) - awal : 0;

                return ScrollablePositionedList.builder(
                  itemCount: akhir - awal,
                  initialScrollIndex: tuju.clamp(0, akhir - awal - 1),
                  itemPositionsListener: _posisi,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  itemBuilder: (context, i) {
                    final a = q.ayat(awal + i);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (a.ayat == 1) _KepalaSurat(quran: q, surat: q.surat[a.surat - 1], ukuran: ukuran),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppColors.garis)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (widget.juz != null)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: AppColors.hijauMuda, borderRadius: BorderRadius.circular(8)),
                                    child: Text(
                                      '${q.surat[a.surat - 1].latin} ${a.surat}:${a.ayat}',
                                      style: text.labelSmall?.copyWith(color: AppColors.hijau, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(text: q.arab(a.surat, a.ayat)),
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: _NomorAyat(nomor: a.ayat, ukuran: ukuran),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.right,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(fontFamily: fontQuran, fontSize: ukuran, height: 2.0, color: AppColors.teks),
                              ),
                              const SizedBox(height: 8),
                              Text(arti[a.surat - 1][a.ayat - 1], style: text.bodyMedium?.copyWith(height: 1.5)),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}
