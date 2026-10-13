import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/akses.dart';
import '../../models/kartu.dart';
import '../../shared/ui.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';
import '../santri/santri_repository.dart';
import 'kartu_pdf.dart';
import 'kartu_widget.dart';

/// Halaman kartu santri. `santriId` null = kartu milik santri yang login.
class KartuPage extends ConsumerStatefulWidget {
  const KartuPage({super.key, this.santriId});

  final int? santriId;

  @override
  ConsumerState<KartuPage> createState() => _KartuPageState();
}

enum _AksiPdf { unduh, unduhGambar, bagikan, cetak }

class _KartuPageState extends ConsumerState<KartuPage> {
  /// Aksi yang sedang diproses (untuk indikator loading di tombolnya).
  _AksiPdf? _proses;

  Future<void> _pdf(KartuSantri kartu, _AksiPdf aksi) async {
    setState(() => _proses = aksi);
    try {
      final api = ref.read(apiClientProvider);
      final foto = kartu.fotoUrl == null ? null : await api.getBytes(kartu.fotoUrl!);
      final bytes = await buatPdfKartu(kartu, foto: foto);
      final nama = 'kartu-santri-${kartu.nis}.pdf';

      switch (aksi) {
        case _AksiPdf.unduh:
          // Android/iOS: jendela "Simpan" bawaan HP (biasanya langsung ke folder Download).
          // Web: file langsung terunduh.
          final lokasi = await FilePicker.saveFile(
            fileName: nama,
            bytes: bytes,
            mimeType: 'application/pdf',
            type: FileType.custom,
            allowedExtensions: ['pdf'],
            dialogTitle: 'Simpan kartu santri',
          );
          if (lokasi != null && mounted) showPesan(context, 'Kartu tersimpan: $nama');
        case _AksiPdf.unduhGambar:
          // PDF diubah menjadi gambar 300 dpi (±1011 × 638 piksel), tampilannya sama persis dengan PDF
          final halaman = await Printing.raster(bytes, pages: [0], dpi: 300).first;
          final png = await halaman.toPng();
          final namaPng = 'kartu-santri-${kartu.nis}.png';
          final lokasi = await FilePicker.saveFile(
            fileName: namaPng,
            bytes: png,
            mimeType: 'image/png',
            type: FileType.custom,
            allowedExtensions: ['png'],
            dialogTitle: 'Simpan gambar kartu santri',
          );
          if (lokasi != null && mounted) showPesan(context, 'Gambar kartu tersimpan: $namaPng');
        case _AksiPdf.bagikan:
          await Printing.sharePdf(bytes: bytes, filename: nama);
        case _AksiPdf.cetak:
          await Printing.layoutPdf(onLayout: (_) async => bytes, name: nama);
      }
    } on ApiException catch (e) {
      if (mounted) showPesan(context, e.message, error: true);
    } catch (e) {
      if (mounted) showPesan(context, 'Gagal membuat PDF: $e', error: true);
    } finally {
      if (mounted) setState(() => _proses = null);
    }
  }

  /// Ikon tombol, atau putaran loading jika aksi tersebut sedang diproses.
  Widget _ikon(_AksiPdf aksi, IconData ikon, Color warna) => _proses == aksi
      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: warna))
      : Icon(ikon);

  Future<void> _qrBaru(KartuSantri kartu) async {
    final ok = await konfirmasi(
      context,
      judul: 'Buat kode QR baru?',
      isi: 'Gunakan ini jika kartu hilang. Kartu lama (yang sudah dicetak) otomatis tidak berlaku dan '
          'kartu baru perlu dicetak ulang.',
      ya: 'Buat QR baru',
      bahaya: true,
    );
    if (!ok) return;

    try {
      await ref.read(santriRepositoryProvider).buatQrBaru(kartu.santriId);
      ref.invalidate(kartuProvider(widget.santriId));
      if (mounted) showPesan(context, 'Kode QR baru dibuat. Silakan cetak ulang kartu.');
    } on ApiException catch (e) {
      if (mounted) showPesan(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const SizedBox.shrink();
    final kartu = ref.watch(kartuProvider(widget.santriId));
    final headers = ref.read(apiClientProvider).authHeaders;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Kartu Santri')),
      body: kartu.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(kartuProvider(widget.santriId))),
        data: (k) => RefreshIndicator(
          onRefresh: () => ref.refresh(kartuProvider(widget.santriId).future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              KartuSantriView(kartu: k, headers: headers),
              const SizedBox(height: 20),
              _StatusKartu(aktif: k.aktif),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _proses != null ? null : () => _pdf(k, _AksiPdf.unduh),
                      icon: _ikon(_AksiPdf.unduh, Icons.picture_as_pdf_outlined, Colors.white),
                      label: const Text('Unduh PDF'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _proses != null ? null : () => _pdf(k, _AksiPdf.unduhGambar),
                      icon: _ikon(_AksiPdf.unduhGambar, Icons.image_outlined, Colors.white),
                      label: const Text('Unduh Gambar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _proses != null ? null : () => _pdf(k, _AksiPdf.bagikan),
                      icon: _ikon(_AksiPdf.bagikan, Icons.share_outlined, AppColors.hijau),
                      label: const Text('Bagikan'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _proses != null ? null : () => _pdf(k, _AksiPdf.cetak),
                      icon: _ikon(_AksiPdf.cetak, Icons.print_outlined, AppColors.hijau),
                      label: const Text('Cetak'),
                    ),
                  ),
                ],
              ),
              if (user.bisaKelolaSantri) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => _qrBaru(k),
                  style: TextButton.styleFrom(foregroundColor: AppColors.merah),
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: const Text('Kartu hilang? Buat kode QR baru'),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'PDF berukuran KTP (85,6 × 54 mm). Saat mencetak, pilih ukuran kertas sesuai kartu '
                'atau cetak di kertas A4 dengan skala 100%.',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: AppColors.teks2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusKartu extends StatelessWidget {
  const _StatusKartu({required this.aktif});

  final bool aktif;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: aktif ? AppColors.hijauMuda : AppColors.oranyeMuda,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(aktif ? Icons.verified_rounded : Icons.error_outline_rounded, color: aktif ? AppColors.hijau : AppColors.oranye),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              aktif
                  ? 'Kartu aktif. Siapa pun dapat memindai kode QR untuk memastikan keaslian kartu ini.'
                  : 'Kartu tidak berlaku karena santri sudah tidak aktif di pondok.',
              style: text.bodySmall?.copyWith(
                color: aktif ? AppColors.hijauTua : AppColors.oranye,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
