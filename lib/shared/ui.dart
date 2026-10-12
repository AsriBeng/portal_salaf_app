import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';

extension KembaliAman on BuildContext {
  /// Kembali ke halaman sebelumnya. Jika halaman dibuka langsung (misalnya lewat URL di web)
  /// dan tidak ada halaman sebelumnya, buka beranda.
  void kembali([Object? hasil]) {
    if (canPop()) {
      pop(hasil);
    } else {
      go('/');
    }
  }
}

/// Pesan singkat di bawah layar.
void showPesan(BuildContext context, String pesan, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(pesan),
      backgroundColor: error ? AppColors.merah : AppColors.hijau,
    ));
}

/// Dialog konfirmasi ya/tidak. Mengembalikan true jika disetujui.
Future<bool> konfirmasi(
  BuildContext context, {
  required String judul,
  required String isi,
  String ya = 'Ya',
  bool bahaya = false,
}) async {
  final hasil = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(judul),
      content: Text(isi),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: bahaya ? AppColors.merah : AppColors.hijau,
            minimumSize: const Size(96, 44),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(ya),
        ),
      ],
    ),
  );
  return hasil ?? false;
}

/// Dialog dengan satu isian teks. Mengembalikan teks (sudah di-trim), atau null jika dibatalkan.
Future<String?> mintaTeks(
  BuildContext context, {
  required String judul,
  required String label,
  String? isi,
  String? hint,
  String? helper,
  String ya = 'Simpan',
  bool bahaya = false,
  bool wajib = true,
  int maxLines = 1,
  String nilaiAwal = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _DialogTeks(
      judul: judul,
      label: label,
      isi: isi,
      hint: hint,
      helper: helper,
      ya: ya,
      bahaya: bahaya,
      wajib: wajib,
      maxLines: maxLines,
      nilaiAwal: nilaiAwal,
    ),
  );
}

class _DialogTeks extends StatefulWidget {
  const _DialogTeks({
    required this.judul,
    required this.label,
    required this.ya,
    required this.bahaya,
    required this.wajib,
    required this.maxLines,
    required this.nilaiAwal,
    this.isi,
    this.hint,
    this.helper,
  });

  final String judul;
  final String label;
  final String? isi;
  final String? hint;
  final String? helper;
  final String ya;
  final bool bahaya;
  final bool wajib;
  final int maxLines;
  final String nilaiAwal;

  @override
  State<_DialogTeks> createState() => _DialogTeksState();
}

class _DialogTeksState extends State<_DialogTeks> {
  // Controller dibuang bersama dialog, setelah animasi tutup selesai
  late final _ctrl = TextEditingController(text: widget.nilaiAwal);
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _kirim() {
    final teks = _ctrl.text.trim();
    if (widget.wajib && teks.isEmpty) {
      setState(() => _error = '${widget.label} wajib diisi.');
      return;
    }
    Navigator.pop(context, teks);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.judul),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.isi != null) ...[Text(widget.isi!), const SizedBox(height: 16)],
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLines: widget.maxLines,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: widget.maxLines == 1 ? (_) => _kirim() : null,
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
              helperText: widget.helper,
              helperMaxLines: 2,
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: widget.bahaya ? AppColors.merah : AppColors.hijau,
            minimumSize: const Size(96, 44),
          ),
          onPressed: _kirim,
          child: Text(widget.ya),
        ),
      ],
    );
  }
}

/// Tampilan saat daftar kosong.
class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.judul, this.isi, this.aksi});

  final IconData icon;
  final String judul;
  final String? isi;
  final Widget? aksi;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(color: AppColors.hijauMuda, shape: BoxShape.circle),
              child: Icon(icon, size: 36, color: AppColors.hijau),
            ),
            const SizedBox(height: 16),
            Text(judul, textAlign: TextAlign.center, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            if (isi != null) ...[
              const SizedBox(height: 6),
              Text(isi!, textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: AppColors.teks2)),
            ],
            if (aksi != null) ...[const SizedBox(height: 20), aksi!],
          ],
        ),
      ),
    );
  }
}

/// Tombol simpan dengan indikator loading.
class TombolSimpan extends StatelessWidget {
  const TombolSimpan({super.key, required this.loading, required this.onPressed, this.label = 'Simpan'});

  final bool loading;
  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
          : Text(label),
    );
  }
}

/// Judul kecil di atas sekelompok field form.
class JudulForm extends StatelessWidget {
  const JudulForm(this.judul, {super.key, this.icon});

  final String judul;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 18, color: AppColors.hijau), const SizedBox(width: 8)],
          Text(
            judul,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.hijau, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet dengan judul, untuk form singkat.
Future<T?> bukaSheet<T>(BuildContext context, {required String judul, required Widget child}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.garis, borderRadius: BorderRadius.circular(99)),
            ),
          ),
          const SizedBox(height: 16),
          Text(judul, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Flexible(child: SingleChildScrollView(child: child)),
        ],
      ),
    ),
  );
}
