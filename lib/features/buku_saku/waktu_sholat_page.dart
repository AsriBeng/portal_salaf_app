import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../shared/ui.dart';
import 'hisab_sholat.dart';
import 'lokasi_sholat.dart';

final _jam = DateFormat('HH:mm');

JadwalSholat _jadwal(LokasiSholat l, DateTime tanggal) => JadwalSholat.hitung(lintang: l.lintang, bujur: l.bujur, tanggal: tanggal);

/// Sholat wajib berikutnya; setelah isya berarti subuh besok.
MapEntry<Waktu, DateTime> _sholatBerikutnya(LokasiSholat l, DateTime sekarang) =>
    _jadwal(l, sekarang).berikutnya(sekarang, hanyaWajib: true) ??
    MapEntry(Waktu.subuh, _jadwal(l, sekarang.add(const Duration(days: 1)))[Waktu.subuh]);

String _sisa(Duration d) {
  final jam = d.inHours;
  final menit = d.inMinutes % 60;
  final detik = d.inSeconds % 60;
  if (jam > 0) return '$jam jam $menit menit';
  if (menit > 0) return '$menit menit $detik detik';
  return '$detik detik';
}

/// Menjalankan [builder] ulang setiap detik.
class _Detak extends StatefulWidget {
  const _Detak({required this.builder});

  final Widget Function(DateTime sekarang) builder;

  @override
  State<_Detak> createState() => _DetakState();
}

class _DetakState extends State<_Detak> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(DateTime.now());
}

/// Kartu hitung mundur ke sholat berikutnya, untuk beranda.
class HitungMundurSholat extends ConsumerWidget {
  const HitungMundurSholat({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lokasi = ref.watch(lokasiSholatProvider).value;
    if (lokasi == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/waktu-sholat'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.garis),
          ),
          child: _Detak(
            builder: (sekarang) {
              final b = _sholatBerikutnya(lokasi, sekarang);
              return Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: AppColors.hijauMuda, borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.mosque_rounded, color: AppColors.hijau),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${b.key.label} ${_jam.format(b.value)}', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        Text(
                          '${_sisa(b.value.difference(sekarang))} lagi',
                          style: text.bodyMedium?.copyWith(color: AppColors.hijau, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          lokasi.nama,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelSmall?.copyWith(color: AppColors.teks2),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.teks2),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class WaktuSholatPage extends ConsumerStatefulWidget {
  const WaktuSholatPage({super.key});

  @override
  ConsumerState<WaktuSholatPage> createState() => _WaktuSholatPageState();
}

class _WaktuSholatPageState extends ConsumerState<WaktuSholatPage> {
  DateTime _tanggal = DateTime.now();
  bool _memuat = false;

  bool get _hariIni => DateUtils.isSameDay(_tanggal, DateTime.now());

  Future<void> _perbarui() async {
    setState(() => _memuat = true);
    try {
      final lokasi = await ref.read(lokasiSholatProvider.notifier).perbarui();
      if (mounted) showPesan(context, 'Lokasi diperbarui: ${lokasi.nama}');
    } on LokasiGagal catch (e) {
      if (mounted) showPesan(context, e.pesan, error: true);
    } catch (_) {
      if (mounted) showPesan(context, 'Lokasi tidak dapat diambil. Coba lagi di tempat terbuka.', error: true);
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lokasi = ref.watch(lokasiSholatProvider).value;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Waktu Sholat')),
      body: lokasi == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: AppColors.gradien),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: AppColors.emas, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              lokasi.nama,
                              style: text.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _Detak(
                        builder: (sekarang) {
                          final b = _sholatBerikutnya(lokasi, sekarang);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${b.key.label} ${_jam.format(b.value)}',
                                style: text.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                '${_sisa(b.value.difference(sekarang))} lagi',
                                style: text.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                        ),
                        onPressed: _memuat ? null : _perbarui,
                        icon: _memuat
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.my_location_rounded, size: 18),
                        label: Text(_memuat ? 'Mengambil lokasi…' : 'Perbarui lokasi'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => setState(() => _tanggal = _tanggal.subtract(const Duration(days: 1))),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _tanggal = DateTime.now()),
                        child: Column(
                          children: [
                            Text(
                              DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_tanggal),
                              textAlign: TextAlign.center,
                              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            if (!_hariIni)
                              Text('Ketuk untuk kembali ke hari ini', style: text.labelSmall?.copyWith(color: AppColors.teks2)),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _tanggal = _tanggal.add(const Duration(days: 1))),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Card(
                  child: _Detak(
                    builder: (sekarang) {
                      final jadwal = _jadwal(lokasi, _tanggal);
                      final berikutnya = _hariIni ? _sholatBerikutnya(lokasi, sekarang).key : null;
                      return Column(
                        children: [
                          for (final w in Waktu.values)
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: w == berikutnya ? AppColors.hijauMuda : null,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    w.label,
                                    style: text.bodyLarge?.copyWith(
                                      fontWeight: w.wajib ? FontWeight.w700 : FontWeight.w500,
                                      color: w.wajib ? AppColors.teks : AppColors.teks2,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _jam.format(jadwal[w]),
                                    style: text.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: w == berikutnya ? AppColors.hijau : (w.wajib ? AppColors.teks : AppColors.teks2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Dihitung dengan kriteria Kemenag RI dari lokasi tersimpan. '
                  'Saat berada di daerah lain, tekan "Perbarui lokasi" agar jadwal mengikuti daerah tersebut.',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: AppColors.teks2, height: 1.45),
                ),
              ],
            ),
    );
  }
}
