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
import 'pilih_santri.dart';

String _bulan(String yyyyMm) => DateFormat('MMM yyyy', 'id_ID').format(DateTime.parse('$yyyyMm-01'));

String _rentang(SppKhusus k) => k.sampai == null
    ? 'Mulai ${_bulan(k.mulai)}'
    : (k.sampai == k.mulai ? _bulan(k.mulai) : '${_bulan(k.mulai)} – ${_bulan(k.sampai!)}');

/// Daftar SPP khusus (potongan / bebas SPP) di halaman jenis tagihan.
class SppKhususSection extends ConsumerWidget {
  const SppKhususSection({super.key, required this.bisaKelola});

  final bool bisaKelola;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daftar = ref.watch(sppKhususProvider);
    final text = Theme.of(context).textTheme;

    Future<void> buka([SppKhusus? k]) async {
      if (k != null && (!bisaKelola || !k.bisaKelola)) {
        await bukaSheet<void>(context, judul: k.nama, child: _DaftarSantri(sppKhusus: k));
        return;
      }
      final ok = await bukaSheet<bool>(
        context,
        judul: k == null ? 'Tambah SPP khusus' : 'Ubah SPP khusus',
        child: _SppKhususForm(sppKhusus: k),
      );
      if (ok == true) ref.invalidate(sppKhususProvider);
    }

    return SectionCard(
      title: 'SPP khusus / potongan',
      trailing: bisaKelola
          ? IconButton(onPressed: buka, icon: const Icon(Icons.add_rounded), tooltip: 'Tambah SPP khusus', visualDensity: VisualDensity.compact)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Santri yang dimasukkan ke SPP khusus ditagih sesuai nominalnya selama rentang bulan yang ditentukan, bukan SPP normal.',
            style: text.bodySmall?.copyWith(color: AppColors.teks2),
          ),
          const SizedBox(height: 4),
          daftar.when(
            loading: () => const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
            error: (e, _) => Text('Gagal memuat: $e', style: const TextStyle(color: AppColors.merah)),
            data: (items) => items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Belum ada SPP khusus.', style: text.bodyMedium?.copyWith(color: AppColors.teks2)),
                  )
                : Column(
                    children: [
                      for (final k in items)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () => buka(k),
                          title: Text(k.nama, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text([
                            k.bebas ? 'Bebas SPP' : '${rupiah(k.nominal)} / bulan',
                            _rentang(k),
                            '${k.santri.length} santri',
                          ].join(' · ')),
                          trailing: k.berlaku ? const Pill(label: 'Berlaku') : null,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _DaftarSantri extends StatelessWidget {
  const _DaftarSantri({required this.sppKhusus});

  final SppKhusus sppKhusus;

  @override
  Widget build(BuildContext context) {
    final k = sppKhusus;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          [k.bebas ? 'Bebas SPP' : '${rupiah(k.nominal)} / bulan', _rentang(k), ?k.keterangan].join(' · '),
          style: text.bodyMedium?.copyWith(color: AppColors.teks2),
        ),
        if (!k.bisaKelola) ...[
          const SizedBox(height: 6),
          Text('Berisi juga santri di luar wewenang Anda, sehingga hanya admin yang dapat mengubahnya.',
              style: text.bodySmall?.copyWith(color: AppColors.teks2)),
        ],
        const SizedBox(height: 8),
        for (final s in k.santri)
          ListTile(contentPadding: EdgeInsets.zero, title: Text(s.namaLengkap), subtitle: Text('NIS ${s.nis}')),
      ],
    );
  }
}

class _SppKhususForm extends ConsumerStatefulWidget {
  const _SppKhususForm({this.sppKhusus});

  final SppKhusus? sppKhusus;

  @override
  ConsumerState<_SppKhususForm> createState() => _SppKhususFormState();
}

class _SppKhususFormState extends ConsumerState<_SppKhususForm> {
  final _form = GlobalKey<FormState>();
  late final _nama = TextEditingController(text: widget.sppKhusus?.nama ?? '');
  late final _nominal = TextEditingController(text: widget.sppKhusus?.bebas == false ? tulisRupiah(widget.sppKhusus!.nominal) : '');
  late final _keterangan = TextEditingController(text: widget.sppKhusus?.keterangan ?? '');
  late bool _bebas = widget.sppKhusus?.bebas ?? false;
  late DateTime _mulai = widget.sppKhusus == null ? DateTime(DateTime.now().year, DateTime.now().month) : DateTime.parse('${widget.sppKhusus!.mulai}-01');
  late DateTime? _sampai = widget.sppKhusus == null ? _mulai : (widget.sppKhusus!.sampai == null ? null : DateTime.parse('${widget.sppKhusus!.sampai}-01'));
  late final _dipilih = {for (final s in widget.sppKhusus?.santri ?? const <SantriSingkat>[]) s.id: s};
  bool _loading = false;

  @override
  void dispose() {
    _nama.dispose();
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

  Future<void> _pilihSantri() async {
    final hasil = await bukaSheet<Map<int, SantriSingkat>>(context, judul: 'Pilih santri', child: PilihSantriSheet(awal: _dipilih));
    if (hasil != null) {
      setState(() => _dipilih
        ..clear()
        ..addAll(hasil));
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(keuanganRepositoryProvider);
    final text = Theme.of(context).textTheme;
    final k = widget.sppKhusus;
    final bulan = DateFormat('yyyy-MM');

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Selama rentang bulan ini, santri yang dipilih ditagih SPP sesuai nominal di bawah. '
            'Tagihan SPP yang sudah terbit dan belum dibayar ikut disesuaikan.',
            style: text.bodySmall?.copyWith(color: AppColors.teks2),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _nama,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nama', hintText: 'contoh: Potongan SPP santri yatim'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi.' : null,
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
          Text('Santri (${_dipilih.length})', style: text.labelLarge),
          const SizedBox(height: 8),
          if (_dipilih.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in _dipilih.values)
                  InputChip(label: Text(s.namaLengkap), onDeleted: () => setState(() => _dipilih.remove(s.id))),
              ],
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: _pilihSantri,
            icon: const Icon(Icons.person_search_rounded),
            label: Text(_dipilih.isEmpty ? 'Pilih santri' : 'Tambah / ubah pilihan'),
          ),
          const SizedBox(height: 18),
          TombolSimpan(
            loading: _loading,
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              if (_dipilih.isEmpty) {
                showPesan(context, 'Pilih minimal satu santri.', error: true);
                return;
              }
              _jalankan(() => repo.simpanSppKhusus(
                    id: k?.id,
                    nama: _nama.text.trim(),
                    nominal: _bebas ? 0 : bacaRupiah(_nominal.text)!,
                    mulai: bulan.format(_mulai),
                    sampai: _sampai == null ? null : bulan.format(_sampai!),
                    keterangan: _keterangan.text.trim().isEmpty ? null : _keterangan.text.trim(),
                    santriIds: _dipilih.keys.toList(),
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
                        judul: 'Hapus ${k.nama}?',
                        isi: 'Tagihan SPP santri-santri ini yang belum dibayar pada rentang ini kembali ke nominal SPP normal.',
                        ya: 'Hapus',
                        bahaya: true,
                      );
                      if (ok) _jalankan(() => repo.hapusSppKhusus(k.id));
                    },
              child: const Text('Hapus SPP khusus'),
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
