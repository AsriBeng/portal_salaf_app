import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/keuangan.dart';
import '../../shared/rupiah_input.dart';
import '../../shared/ui.dart';
import '../../shared/widgets.dart';
import 'keuangan_repository.dart';
import 'keuangan_widgets.dart';

String _bulan(String yyyyMm) => DateFormat('MMM yyyy', 'id_ID').format(DateTime.parse('$yyyyMm-01'));

/// Kartu keringanan SPP di detail santri (admin, ketua, bendahara).
class KeringananSppCard extends ConsumerWidget {
  const KeringananSppCard({super.key, required this.santriId, required this.bisaKelola});

  final int santriId;
  final bool bisaKelola;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daftar = ref.watch(keringananSppProvider(santriId));
    final text = Theme.of(context).textTheme;

    Future<void> buka([KeringananSpp? k]) async {
      final ok = await bukaSheet<bool>(
        context,
        judul: k == null ? 'Tambah keringanan SPP' : 'Ubah keringanan SPP',
        child: _KeringananForm(santriId: santriId, keringanan: k),
      );
      if (ok == true) ref.invalidate(keringananSppProvider(santriId));
    }

    return SectionCard(
      title: 'Keringanan SPP',
      trailing: bisaKelola
          ? IconButton(onPressed: buka, icon: const Icon(Icons.add_rounded), tooltip: 'Tambah keringanan', visualDensity: VisualDensity.compact)
          : null,
      child: daftar.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text('Gagal memuat: $e', style: const TextStyle(color: AppColors.merah)),
        data: (items) => items.isEmpty
            ? Text('SPP normal, tidak ada keringanan.', style: text.bodyMedium?.copyWith(color: AppColors.teks2))
            : Column(
                children: [
                  for (final k in items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: bisaKelola ? () => buka(k) : null,
                      title: Text(k.bebas ? 'Bebas SPP' : '${rupiah(k.nominal)} / bulan', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        [
                          k.sampai == null ? 'Mulai ${_bulan(k.mulai)}' : (k.sampai == k.mulai ? _bulan(k.mulai) : '${_bulan(k.mulai)} – ${_bulan(k.sampai!)}'),
                          ?k.keterangan,
                        ].join(' · '),
                      ),
                      trailing: k.berlaku ? const Pill(label: 'Berlaku') : null,
                    ),
                ],
              ),
      ),
    );
  }
}

class _KeringananForm extends ConsumerStatefulWidget {
  const _KeringananForm({required this.santriId, this.keringanan});

  final int santriId;
  final KeringananSpp? keringanan;

  @override
  ConsumerState<_KeringananForm> createState() => _KeringananFormState();
}

class _KeringananFormState extends ConsumerState<_KeringananForm> {
  final _form = GlobalKey<FormState>();
  late final _nominal = TextEditingController(text: widget.keringanan?.bebas == false ? tulisRupiah(widget.keringanan!.nominal) : '');
  late final _keterangan = TextEditingController(text: widget.keringanan?.keterangan ?? '');
  late bool _bebas = widget.keringanan?.bebas ?? false;
  late DateTime _mulai = widget.keringanan == null ? DateTime(DateTime.now().year, DateTime.now().month) : DateTime.parse('${widget.keringanan!.mulai}-01');
  late DateTime? _sampai = widget.keringanan == null ? _mulai : (widget.keringanan!.sampai == null ? null : DateTime.parse('${widget.keringanan!.sampai}-01'));
  bool _loading = false;

  @override
  void dispose() {
    _nominal.dispose();
    _keterangan.dispose();
    super.dispose();
  }

  Future<void> _jalankan(Future<String> Function() aksi) async {
    setState(() => _loading = true);
    try {
      final pesan = await aksi();
      if (mounted) {
        showPesan(context, pesan);
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) showPesan(context, e.errors.values.firstOrNull?.first ?? e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(keuanganRepositoryProvider);
    final text = Theme.of(context).textTheme;
    final k = widget.keringanan;
    final bulan = DateFormat('yyyy-MM');

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Selama rentang bulan ini, tagihan SPP santri memakai nominal di bawah. '
            'Tagihan SPP yang sudah terbit dan belum dibayar ikut disesuaikan.',
            style: text.bodySmall?.copyWith(color: AppColors.teks2),
          ),
          SwitchListTile(
            value: _bebas,
            onChanged: (v) => setState(() => _bebas = v),
            contentPadding: EdgeInsets.zero,
            title: const Text('Bebas SPP'),
            subtitle: const Text('Tidak dibuatkan tagihan SPP sama sekali.'),
          ),
          if (!_bebas) ...[
            RupiahField(controller: _nominal, label: 'SPP per bulan'),
            const SizedBox(height: 14),
          ],
          Text('Mulai', style: text.labelLarge),
          _PilihBulan(
            value: _mulai,
            onChanged: (b) => setState(() {
              _mulai = b;
              if (_sampai != null && _sampai!.isBefore(b)) _sampai = b;
            }),
          ),
          SwitchListTile(
            value: _sampai == null,
            onChanged: (v) => setState(() => _sampai = v ? null : _mulai),
            contentPadding: EdgeInsets.zero,
            title: const Text('Tanpa batas waktu'),
          ),
          if (_sampai != null) ...[
            Text('Sampai', style: text.labelLarge),
            _PilihBulan(value: _sampai!, minimal: _mulai, onChanged: (b) => setState(() => _sampai = b)),
          ],
          const SizedBox(height: 8),
          TextFormField(
            controller: _keterangan,
            decoration: const InputDecoration(labelText: 'Keterangan (opsional)', hintText: 'contoh: Keringanan khusus dari pondok'),
          ),
          const SizedBox(height: 18),
          TombolSimpan(
            loading: _loading,
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              _jalankan(() => repo.simpanKeringananSpp(
                    id: k?.id,
                    santriId: widget.santriId,
                    nominal: _bebas ? 0 : bacaRupiah(_nominal.text)!,
                    mulai: bulan.format(_mulai),
                    sampai: _sampai == null ? null : bulan.format(_sampai!),
                    keterangan: _keterangan.text.trim().isEmpty ? null : _keterangan.text.trim(),
                  ));
            },
          ),
          if (k != null) ...[
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.merah),
              onPressed: _loading
                  ? null
                  : () async {
                      final ok = await konfirmasi(
                        context,
                        judul: 'Hapus keringanan?',
                        isi: 'Tagihan SPP yang belum dibayar pada rentang ini kembali ke nominal SPP normal.',
                        ya: 'Hapus',
                        bahaya: true,
                      );
                      if (ok) _jalankan(() => repo.hapusKeringananSpp(k.id));
                    },
              child: const Text('Hapus keringanan'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PilihBulan extends StatelessWidget {
  const _PilihBulan({required this.value, required this.onChanged, this.minimal});

  final DateTime value;
  final DateTime? minimal;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final sebelum = DateTime(value.year, value.month - 1);
    return Row(
      children: [
        IconButton(
          onPressed: minimal != null && sebelum.isBefore(minimal!) ? null : () => onChanged(sebelum),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            DateFormat('MMMM yyyy', 'id_ID').format(value),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
        IconButton(
          onPressed: () => onChanged(DateTime(value.year, value.month + 1)),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}
