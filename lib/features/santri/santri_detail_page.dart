import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/akses.dart';
import '../../models/santri.dart';
import '../../models/user.dart';
import '../../shared/ui.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';
import '../keuangan/keringanan_spp.dart';
import '../komplek/komplek_pages.dart';
import 'santri_repository.dart';

class SantriDetailPage extends ConsumerWidget {
  /// `id` null = data diri santri yang sedang login (dipakai santri / wali).
  const SantriDetailPage({super.key, this.id});

  final int? id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const SizedBox.shrink();
    final provider = id == null ? santriSayaProvider : santriDetailProvider(id!);
    final detail = ref.watch(provider);
    final santri = detail.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(id == null ? 'Data Diri' : 'Detail Santri'),
        actions: [
          if (santri != null && user.bisaKelolaSantri) _MenuAksi(santri: santri),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(provider)),
        data: (s) => RefreshIndicator(
          onRefresh: () => ref.refresh(provider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              _Header(santri: s, user: user),
              const SizedBox(height: 16),
              _TombolCepat(santri: s, user: user),
              if (id == null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.emasMuda, borderRadius: BorderRadius.circular(14)),
                  child: Text(
                    'Jika ada data yang keliru atau dokumen yang perlu diperbarui, silakan hubungi sekretaris pondok.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B5500), height: 1.45),
                  ),
                ),
              const SizedBox(height: 16),
              if (s.lengkap) ...[
                _Bagian(judul: 'Identitas', baris: [
                  ('NIK', s.field('nik')),
                  ('Nomor KK', s.field('no_kk')),
                  ('Tempat, tanggal lahir', '${s.tempatLahir}, ${tanggal(s.tanggalLahir)}'),
                  ('Jenis kelamin', s.putri ? 'Perempuan' : 'Laki-laki'),
                  ('Agama', s.field('agama')),
                  ('Kewarganegaraan', s.field('kewarganegaraan')),
                  ('Anak ke / saudara', [s.field('anak_ke'), s.field('jumlah_saudara')].every((v) => v == null)
                      ? null
                      : '${s.field('anak_ke') ?? '-'} dari ${(int.tryParse(s.field('jumlah_saudara') ?? '') ?? 0) + 1} bersaudara'),
                  ('No. telepon', s.field('no_telepon')),
                ]),
                const SizedBox(height: 16),
                _Bagian(judul: 'Alamat asal', baris: [
                  ('Alamat', s.field('alamat')),
                  ('RT / RW', s.field('rt') == null && s.field('rw') == null ? null : '${s.field('rt') ?? '-'} / ${s.field('rw') ?? '-'}'),
                  ('Desa / kelurahan', s.field('kelurahan')),
                  ('Kecamatan', s.field('kecamatan')),
                  ('Kabupaten / kota', s.field('kabupaten')),
                  ('Provinsi', s.field('provinsi')),
                  ('Kode pos', s.field('kode_pos')),
                ]),
                const SizedBox(height: 16),
                _Bagian(judul: 'Orang tua & wali', baris: [
                  ('Ayah', s.field('nama_ayah')),
                  ('Pekerjaan ayah', s.field('pekerjaan_ayah')),
                  ('Telepon ayah', s.field('no_telepon_ayah')),
                  ('Ibu', s.field('nama_ibu')),
                  ('Pekerjaan ibu', s.field('pekerjaan_ibu')),
                  ('Telepon ibu', s.field('no_telepon_ibu')),
                  ('Wali', s.field('nama_wali') == null ? null : '${s.field('nama_wali')} (${s.field('hubungan_wali') ?? 'wali'})'),
                  ('Telepon wali', s.field('no_telepon_wali')),
                ]),
                const SizedBox(height: 16),
              ],
              _Bagian(judul: 'Data pondok', baris: [
                ('Status', s.status.label),
                ('Komplek', s.kamar?.komplek?.nama),
                ('Kamar', s.kamar?.nama ?? 'Belum ditempatkan'),
                ('Tanggal masuk', tanggal(s.tanggalMasuk)),
                ('Tanggal keluar', s.tanggalKeluar == null ? null : tanggal(s.tanggalKeluar)),
              ]),
              if (id != null && user.bisaLihatKeuangan) ...[
                const SizedBox(height: 16),
                KeringananSppCard(santriId: s.id, bisaKelola: user.bisaKelolaKeuangan),
              ],
              if (s.lengkap) ...[
                const SizedBox(height: 16),
                _Dokumen(santri: s, bisaUnggah: user.bisaKelolaSantri),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.santri, required this.user});

  final Santri santri;
  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final headers = ref.read(apiClientProvider).authHeaders;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: AppColors.gradien, borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          Container(
            width: 84,
            height: 112,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.emasMuda,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: santri.fotoUrl == null
                ? Center(
                    child: Text(santri.inisial,
                        style: const TextStyle(color: AppColors.hijau, fontSize: 28, fontWeight: FontWeight.w800)),
                  )
                : Image.network(santri.fotoUrl!, headers: headers, fit: BoxFit.cover),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(santri.namaLengkap, style: text.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('NIS ${santri.nis}', style: text.bodyMedium?.copyWith(color: AppColors.emas, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    GenderPill(santri.jenisKelamin),
                    santri.status == StatusSantri.aktif
                        ? const Pill(label: 'Aktif')
                        : Pill(label: santri.status.label, color: AppColors.oranye, background: AppColors.oranyeMuda),
                    if (santri.isActive == false)
                      const Pill(label: 'Akun nonaktif', color: AppColors.merah, background: AppColors.merahMuda),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TombolCepat extends StatelessWidget {
  const _TombolCepat({required this.santri, required this.user});

  final Santri santri;
  final User user;

  @override
  Widget build(BuildContext context) {
    final tombol = <Widget>[
      if (user.bisaLihatKartu)
        Expanded(
          child: FilledButton.icon(
            onPressed: () => context.push('/santri/${santri.id}/kartu'),
            icon: const Icon(Icons.badge_rounded),
            label: const Text('Kartu santri'),
          ),
        ),
      if (user.bisaKelolaSantri)
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.push('/santri/${santri.id}/ubah'),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Ubah data'),
          ),
        ),
      if (user.bisaLihatKeuangan)
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.push('/tagihan-santri/${santri.id}?nama=${Uri.encodeComponent(santri.namaLengkap)}'),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Tagihan'),
          ),
        ),
    ];

    if (tombol.isEmpty) return const SizedBox.shrink();
    return Row(children: [for (final (i, t) in tombol.indexed) ...[if (i > 0) const SizedBox(width: 12), t]]);
  }
}

class _Bagian extends StatelessWidget {
  const _Bagian({required this.judul, required this.baris});

  final String judul;
  final List<(String, String?)> baris;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isi = baris.where((b) => b.$2 != null && b.$2!.trim().isNotEmpty).toList();

    return SectionCard(
      title: judul,
      child: Column(
        children: [
          for (final (label, nilai) in isi)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(label, style: text.bodyMedium?.copyWith(color: AppColors.teks2)),
                  ),
                  Expanded(child: Text(nilai!, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                ],
              ),
            ),
          if (isi.isEmpty) Text('Belum diisi.', style: text.bodyMedium?.copyWith(color: AppColors.teks2)),
        ],
      ),
    );
  }
}

/// Daftar dokumen (foto, KK, akta, KTP) dengan tombol lihat dan unggah.
class _Dokumen extends ConsumerStatefulWidget {
  const _Dokumen({required this.santri, required this.bisaUnggah});

  final Santri santri;
  final bool bisaUnggah;

  @override
  ConsumerState<_Dokumen> createState() => _DokumenState();
}

class _DokumenState extends ConsumerState<_Dokumen> {
  JenisDokumen? _sibuk;

  String? _url(JenisDokumen jenis) =>
      jenis == JenisDokumen.fotoProfil ? widget.santri.fotoUrl : widget.santri.dokumen[jenis.key];

  Future<void> _lihat(JenisDokumen jenis) async {
    setState(() => _sibuk = jenis);
    try {
      final bytes = await ref.read(apiClientProvider).getBytes(_url(jenis)!);
      if (!mounted) return;
      final pdf = bytes.length > 4 && String.fromCharCodes(bytes.sublist(0, 4)) == '%PDF';
      if (pdf) {
        await Printing.sharePdf(bytes: bytes, filename: '${jenis.key}-${widget.santri.nis}.pdf');
      } else {
        await _tampilGambar(jenis.label, bytes);
      }
    } on ApiException catch (e) {
      if (mounted) showPesan(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _sibuk = null);
    }
  }

  Future<void> _tampilGambar(String judul, Uint8List bytes) => showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(judul, style: const TextStyle(fontWeight: FontWeight.w800)),
                trailing: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
              ),
              Flexible(child: InteractiveViewer(child: Image.memory(bytes))),
            ],
          ),
        ),
      );

  Future<void> _unggah(JenisDokumen jenis) async {
    UploadFile? file;

    if (jenis == JenisDokumen.fotoProfil) {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 900, imageQuality: 85);
      if (x != null) file = UploadFile(x.name, await x.readAsBytes());
    } else {
      final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf']);
      if (f != null) file = UploadFile(f.name, await f.readAsBytes());
    }
    if (file == null) return;

    if (file.bytes.length > 4 * 1024 * 1024) {
      if (mounted) showPesan(context, 'Ukuran file maksimal 4 MB.', error: true);
      return;
    }

    setState(() => _sibuk = jenis);
    try {
      await ref.read(santriRepositoryProvider).uploadDokumen(widget.santri.id, jenis, file);
      ref.invalidate(santriDetailProvider(widget.santri.id));
      if (mounted) showPesan(context, '${jenis.label} berhasil diunggah.');
    } on ApiException catch (e) {
      if (mounted) showPesan(context, e.errors.values.firstOrNull?.first ?? e.message, error: true);
    } finally {
      if (mounted) setState(() => _sibuk = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return SectionCard(
      title: 'Dokumen',
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Column(
        children: [
          for (final jenis in JenisDokumen.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _url(jenis) != null ? AppColors.hijauMuda : AppColors.latar,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      jenis == JenisDokumen.fotoProfil ? Icons.portrait_rounded : Icons.description_outlined,
                      size: 20,
                      color: _url(jenis) != null ? AppColors.hijau : AppColors.teks2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(jenis.label, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                        Text(
                          _url(jenis) != null ? 'Sudah diunggah' : 'Belum diunggah',
                          style: text.bodySmall?.copyWith(color: _url(jenis) != null ? AppColors.hijau : AppColors.teks2),
                        ),
                      ],
                    ),
                  ),
                  if (_sibuk == jenis)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
                    )
                  else ...[
                    if (_url(jenis) != null)
                      IconButton(
                        tooltip: 'Lihat',
                        onPressed: _sibuk == null ? () => _lihat(jenis) : null,
                        icon: const Icon(Icons.visibility_outlined),
                      ),
                    if (widget.bisaUnggah)
                      IconButton(
                        tooltip: _url(jenis) != null ? 'Ganti' : 'Unggah',
                        onPressed: _sibuk == null ? () => _unggah(jenis) : null,
                        icon: Icon(_url(jenis) != null ? Icons.sync_rounded : Icons.upload_rounded, color: AppColors.hijau),
                      ),
                  ],
                ],
              ),
            ),
          if (widget.bisaUnggah)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 8),
              child: Text(
                'Format JPG, PNG, atau PDF. Maksimal 4 MB (foto profil 2 MB).',
                style: text.labelSmall?.copyWith(color: AppColors.teks2),
              ),
            ),
        ],
      ),
    );
  }
}

/// Menu titik tiga: reset password, aktif/nonaktifkan akun, hapus.
class _MenuAksi extends ConsumerWidget {
  const _MenuAksi({required this.santri});

  final Santri santri;

  Future<void> _resetPassword(BuildContext context, WidgetRef ref) async {
    final password = await mintaTeks(
      context,
      judul: 'Reset password',
      isi: 'Password ${santri.namaLengkap} akan diganti dan akun keluar dari semua perangkat.',
      label: 'Password baru (opsional)',
      helper: 'Kosongkan = tanggal lahir (ddmmyyyy)',
      ya: 'Reset',
      wajib: false,
    );
    if (password == null) return;

    if (password.isNotEmpty && password.length < 6) {
      if (context.mounted) showPesan(context, 'Password minimal 6 karakter.', error: true);
      return;
    }

    try {
      final pesan = await ref.read(santriRepositoryProvider).resetPassword(santri.id, password: password);
      if (context.mounted) showPesan(context, pesan);
    } on ApiException catch (e) {
      if (context.mounted) showPesan(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aktif = santri.isActive ?? true;

    return PopupMenuButton<String>(
      onSelected: (aksi) async {
        final repo = ref.read(santriRepositoryProvider);
        switch (aksi) {
          case 'reset':
            await _resetPassword(context, ref);
          case 'akun':
            final ok = await konfirmasi(
              context,
              judul: aktif ? 'Nonaktifkan akun?' : 'Aktifkan akun?',
              isi: aktif
                  ? 'Santri tidak bisa login sampai akunnya diaktifkan kembali. Data santri tetap tersimpan.'
                  : 'Santri bisa login kembali dengan NIS dan password-nya.',
              ya: aktif ? 'Nonaktifkan' : 'Aktifkan',
              bahaya: aktif,
            );
            if (!ok) return;
            try {
              final pesan = await repo.setAktif(santri.id, !aktif);
              ref.invalidate(santriDetailProvider(santri.id));
              if (context.mounted) showPesan(context, pesan);
            } on ApiException catch (e) {
              if (context.mounted) showPesan(context, e.message, error: true);
            }
          case 'hapus':
            final ok = await konfirmasi(
              context,
              judul: 'Hapus santri?',
              isi: 'Data ${santri.namaLengkap} akan dihapus dan akunnya dinonaktifkan. '
                  'Jika santri lulus atau keluar, sebaiknya ubah statusnya saja.',
              ya: 'Hapus',
              bahaya: true,
            );
            if (!ok) return;
            try {
              await repo.hapus(santri.id);
              if (context.mounted) {
                showPesan(context, 'Data santri dihapus.');
                context.kembali();
              }
            } on ApiException catch (e) {
              if (context.mounted) showPesan(context, e.message, error: true);
            }
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'reset',
          child: ListTile(leading: Icon(Icons.lock_reset_rounded), title: Text('Reset password'), contentPadding: EdgeInsets.zero),
        ),
        PopupMenuItem(
          value: 'akun',
          child: ListTile(
            leading: Icon(aktif ? Icons.person_off_outlined : Icons.person_outline_rounded),
            title: Text(aktif ? 'Nonaktifkan akun' : 'Aktifkan akun'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'hapus',
          child: ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: AppColors.merah),
            title: Text('Hapus santri', style: TextStyle(color: AppColors.merah)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
