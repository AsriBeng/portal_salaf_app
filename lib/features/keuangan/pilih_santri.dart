import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/keuangan.dart';
import '../../models/santri.dart';
import '../santri/santri_repository.dart';

/// Isi [bukaSheet] untuk memilih beberapa santri; mengembalikan pilihan akhir saat ditutup dengan tombol.
class PilihSantriSheet extends ConsumerStatefulWidget {
  const PilihSantriSheet({super.key, required this.awal});

  final Map<int, SantriSingkat> awal;

  @override
  ConsumerState<PilihSantriSheet> createState() => _PilihSantriSheetState();
}

class _PilihSantriSheetState extends ConsumerState<PilihSantriSheet> {
  late final _dipilih = Map<int, SantriSingkat>.of(widget.awal);
  Timer? _jeda;
  late Future<Halaman<Santri>> _hasil = _cari('');

  Future<Halaman<Santri>> _cari(String kata) => ref.read(santriRepositoryProvider).daftar(search: kata);

  @override
  void dispose() {
    _jeda?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Cari nama atau NIS', prefixIcon: Icon(Icons.search_rounded)),
          onChanged: (v) {
            _jeda?.cancel();
            _jeda = Timer(const Duration(milliseconds: 450), () => setState(() => _hasil = _cari(v.trim())));
          },
        ),
        const SizedBox(height: 8),
        FutureBuilder<Halaman<Santri>>(
          future: _hasil,
          builder: (context, snap) {
            if (snap.hasError) return Text('${snap.error}', style: const TextStyle(color: AppColors.merah));
            if (!snap.hasData) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
            final halaman = snap.data!;
            if (halaman.items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Santri tidak ditemukan.', textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: AppColors.teks2)),
              );
            }
            return Column(
              children: [
                for (final s in halaman.items)
                  CheckboxListTile(
                    value: _dipilih.containsKey(s.id),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.hijau,
                    title: Text(s.namaLengkap, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('NIS ${s.nis}'),
                    onChanged: (v) => setState(() => v == true
                        ? _dipilih[s.id] = SantriSingkat(id: s.id, nis: s.nis, namaLengkap: s.namaLengkap, jenisKelamin: s.jenisKelamin)
                        : _dipilih.remove(s.id)),
                  ),
                if (halaman.adaLagi)
                  Text('Ketik nama untuk mencari santri lainnya.', style: text.labelSmall?.copyWith(color: AppColors.teks2)),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: () => Navigator.pop(context, _dipilih),
          child: Text(_dipilih.isEmpty ? 'Selesai' : 'Pilih ${_dipilih.length} santri'),
        ),
      ],
    );
  }
}
