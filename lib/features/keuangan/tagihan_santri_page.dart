import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/keuangan.dart';
import '../../shared/paged_list.dart';
import '../../shared/rupiah_input.dart';
import '../../shared/ui.dart';
import '../home/dashboard_provider.dart';
import 'keuangan_repository.dart';
import 'keuangan_widgets.dart';

/// Tab Tagihan untuk santri / wali: tagihan belum lunas, lunas, dan riwayat pembayaran.
class TagihanSantriPage extends ConsumerStatefulWidget {
  const TagihanSantriPage({super.key});

  @override
  ConsumerState<TagihanSantriPage> createState() => _TagihanSantriPageState();
}

class _TagihanSantriPageState extends ConsumerState<TagihanSantriPage> {
  int _versi = 0;
  RingkasanTagihan? _ringkasan;

  Future<void> _buka(String path) async {
    await context.push(path);
    if (!mounted) return;
    setState(() => _versi++);
    ref.invalidate(dashboardProvider);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(keuanganRepositoryProvider);
    final text = Theme.of(context).textTheme;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tagihan'),
          bottom: const TabBar(
            labelColor: AppColors.hijau,
            indicatorColor: AppColors.hijau,
            labelStyle: TextStyle(fontWeight: FontWeight.w700),
            tabs: [Tab(text: 'Belum lunas'), Tab(text: 'Lunas'), Tab(text: 'Riwayat bayar')],
          ),
        ),
        body: TabBarView(
          children: [
            PagedList<Tagihan>(
              reloadKey: 'belum-$_versi',
              muat: (page) async {
                final h = await repo.tagihan(page: page, belumLunas: true);
                if (page == 1 && mounted) setState(() => _ringkasan = h.ringkasan);
                return h.halaman;
              },
              header: _ringkasan == null || _ringkasan!.jumlah == 0 ? null : _TotalTunggakan(ringkasan: _ringkasan!),
              itemBuilder: (_, t) => TagihanCard(tagihan: t, tampilSantri: false, onTap: () => _buka('/tagihan/${t.id}')),
              kosong: const EmptyView(
                icon: Icons.verified_rounded,
                judul: 'Alhamdulillah, semua lunas',
                isi: 'Tidak ada tagihan yang perlu dibayar saat ini.',
              ),
            ),
            PagedList<Tagihan>(
              reloadKey: 'lunas-$_versi',
              muat: (page) async => (await repo.tagihan(page: page, status: 'lunas')).halaman,
              itemBuilder: (_, t) => TagihanCard(tagihan: t, tampilSantri: false, onTap: () => _buka('/tagihan/${t.id}')),
              kosong: const EmptyView(icon: Icons.receipt_long_outlined, judul: 'Belum ada tagihan lunas'),
            ),
            PagedList<Pembayaran>(
              reloadKey: 'riwayat-$_versi',
              muat: (page) => repo.pembayaran(page: page),
              itemBuilder: (_, p) => _RiwayatTile(pembayaran: p, onTap: () => _buka('/pembayaran/${p.id}')),
              kosong: EmptyView(
                icon: Icons.history_rounded,
                judul: 'Belum ada pembayaran',
                isi: 'Bukti transfer yang Anda kirim akan muncul di sini beserta statusnya.',
                aksi: Text('Tarik ke bawah untuk memuat ulang.', style: text.labelSmall?.copyWith(color: AppColors.teks2)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalTunggakan extends StatelessWidget {
  const _TotalTunggakan({required this.ringkasan});

  final RingkasanTagihan ringkasan;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: AppColors.gradien, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total belum dibayar', style: text.labelLarge?.copyWith(color: Colors.white70)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(rupiah(ringkasan.sisa), style: text.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: AppColors.emas, borderRadius: BorderRadius.circular(99)),
            child: Text(
              '${ringkasan.jumlah} tagihan',
              style: text.labelMedium?.copyWith(color: AppColors.hijauTua, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _RiwayatTile extends StatelessWidget {
  const _RiwayatTile({required this.pembayaran, required this.onTap});

  final Pembayaran pembayaran;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = pembayaran;
    final (ikon, warna, latar) = switch (p.status) {
      StatusPembayaran.disetujui => (Icons.check_circle_rounded, AppColors.hijau, AppColors.hijauMuda),
      StatusPembayaran.menunggu => (Icons.hourglass_top_rounded, AppColors.oranye, AppColors.oranyeMuda),
      StatusPembayaran.ditolak => (Icons.cancel_rounded, AppColors.merah, AppColors.merahMuda),
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
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
                    Text(p.tagihan?.judul ?? 'Pembayaran', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    Text('${p.metodeLabel} · ${tanggal(p.tanggalBayar)}', style: text.bodySmall?.copyWith(color: AppColors.teks2)),
                    if (p.status == StatusPembayaran.ditolak && p.alasanTolak != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Ditolak: ${p.alasanTolak}',
                        style: text.bodySmall?.copyWith(color: AppColors.merah, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(rupiah(p.nominal), style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  StatusPembayaranPill(p.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Form santri / wali mengirim bukti transfer untuk satu tagihan.
class UploadBuktiForm extends ConsumerStatefulWidget {
  const UploadBuktiForm({super.key, required this.tagihan, required this.maks});

  final Tagihan tagihan;

  /// Sisa tagihan dikurangi pembayaran yang masih menunggu verifikasi
  final int maks;

  @override
  ConsumerState<UploadBuktiForm> createState() => _UploadBuktiFormState();
}

class _UploadBuktiFormState extends ConsumerState<UploadBuktiForm> {
  final _form = GlobalKey<FormState>();
  late final _nominal = TextEditingController(text: tulisRupiah(widget.maks));
  final _catatan = TextEditingController();
  DateTime _tanggal = DateTime.now();
  UploadFile? _bukti;
  bool _loading = false;
  String? _errorNominal;

  @override
  void dispose() {
    _nominal.dispose();
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _pilihBukti() async {
    // Di web kamera tidak tersedia, langsung buka pemilih file
    final sumber = kIsWeb
        ? ImageSource.gallery
        : await showModalBottomSheet<ImageSource>(
            context: context,
            builder: (context) => SafeArea(
              child: Wrap(children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Foto dengan kamera'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Pilih screenshot / foto dari galeri'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ]),
            ),
          );
    if (sumber == null) return;

    UploadFile? file;
    if (kIsWeb) {
      final f = await FilePicker.pickFile(type: FileType.image);
      if (f != null) file = UploadFile(f.name, await f.readAsBytes());
    } else {
      final x = await ImagePicker().pickImage(source: sumber, maxWidth: 1600, imageQuality: 80);
      if (x != null) file = UploadFile(x.name, await x.readAsBytes());
    }
    if (file == null) return;

    if (file.bytes.length > 4 * 1024 * 1024) {
      if (mounted) showPesan(context, 'Ukuran gambar maksimal 4 MB.', error: true);
      return;
    }
    setState(() => _bukti = file);
  }

  Future<void> _kirim() async {
    setState(() => _errorNominal = null);
    if (!_form.currentState!.validate()) return;
    if (_bukti == null) {
      showPesan(context, 'Lampirkan foto atau screenshot bukti transfer.', error: true);
      return;
    }

    setState(() => _loading = true);
    try {
      final pesan = await ref.read(keuanganRepositoryProvider).bayar(
            tagihanId: widget.tagihan.id,
            nominal: bacaRupiah(_nominal.text)!,
            tanggalBayar: isoTanggal(_tanggal),
            catatan: _catatan.text.trim(),
            bukti: _bukti,
          );
      if (!mounted) return;
      showPesan(context, pesan);
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorNominal = e.fieldError('nominal'));
      _form.currentState!.validate();
      if (e.fieldError('nominal') == null) showPesan(context, e.errors.values.firstOrNull?.first ?? e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.tagihan.judul} · bisa dibayar hingga ${rupiah(widget.maks)}',
            style: text.bodyMedium?.copyWith(color: AppColors.teks2),
          ),
          const SizedBox(height: 16),
          RupiahField(
            controller: _nominal,
            label: 'Nominal yang ditransfer',
            maks: widget.maks,
            helper: 'Boleh dicicil (kurang dari sisa tagihan).',
            errorServer: _errorNominal,
          ),
          const SizedBox(height: 14),
          TanggalField(
            label: 'Tanggal transfer',
            value: _tanggal,
            lastDate: DateTime.now(),
            onChanged: (d) => setState(() => _tanggal = d ?? _tanggal),
          ),
          const SizedBox(height: 14),

          // Bukti transfer
          InkWell(
            onTap: _pilihBukti,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: _bukti == null ? 120 : 220,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: _bukti == null ? AppColors.hijauMuda : Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _bukti == null ? const Color(0xFFBFE3CE) : AppColors.garis, width: 1.5),
              ),
              child: _bukti == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_photo_alternate_outlined, size: 34, color: AppColors.hijau),
                        const SizedBox(height: 8),
                        Text('Tambahkan bukti transfer *', style: text.titleSmall?.copyWith(color: AppColors.hijau, fontWeight: FontWeight.w800)),
                        Text('Foto struk atau screenshot m-banking', style: text.bodySmall?.copyWith(color: AppColors.teks2)),
                      ],
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(_bukti!.bytes, fit: BoxFit.contain),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: FilledButton.tonalIcon(
                            onPressed: _pilihBukti,
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
                            icon: const Icon(Icons.sync_rounded, size: 18),
                            label: const Text('Ganti'),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _catatan,
            decoration: const InputDecoration(labelText: 'Catatan (opsional)', hintText: 'contoh: transfer dari rekening ayah'),
          ),
          const SizedBox(height: 18),
          TombolSimpan(loading: _loading, onPressed: _kirim, label: 'Kirim bukti pembayaran'),
          const SizedBox(height: 8),
          Text(
            'Bendahara akan mengecek bukti Anda. Anda akan mendapat notifikasi setelah pembayaran disetujui atau ditolak.',
            textAlign: TextAlign.center,
            style: text.labelSmall?.copyWith(color: AppColors.teks2, height: 1.4),
          ),
        ],
      ),
    );
  }
}
