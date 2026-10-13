import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/user.dart';
import '../../shared/paged_list.dart';
import '../../shared/pilih_foto.dart';
import '../../shared/ui.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';
import '../komplek/komplek_forms.dart';
import '../komplek/komplek_pages.dart';
import 'admin_repository.dart';

/// Kelola akun pengurus (khusus admin): ketua, sekretaris, bendahara putra/putri, dan admin lain.
class PengurusPage extends ConsumerStatefulWidget {
  const PengurusPage({super.key});

  @override
  ConsumerState<PengurusPage> createState() => _PengurusPageState();
}

class _PengurusPageState extends ConsumerState<PengurusPage> {
  final _cari = TextEditingController();
  Timer? _jeda;
  String _kata = '';
  String? _role;
  int _versi = 0;

  @override
  void dispose() {
    _jeda?.cancel();
    _cari.dispose();
    super.dispose();
  }

  Future<void> _form([Pengurus? p]) async {
    final ok = await bukaSheet<bool>(
      context,
      judul: p == null ? 'Tambah pengurus' : 'Ubah ${p.user.name}',
      child: _PengurusForm(pengurus: p),
    );
    if (ok == true) setState(() => _versi++);
  }

  Future<void> _aksi(Pengurus p) async {
    final saya = ref.read(authControllerProvider).value;
    final aksi = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Ubah data'),
            onTap: () => Navigator.pop(context, 'ubah'),
          ),
          ListTile(
            leading: const Icon(Icons.add_a_photo_outlined),
            title: const Text('Ganti foto profil'),
            onTap: () => Navigator.pop(context, 'foto'),
          ),
          ListTile(
            leading: const Icon(Icons.lock_reset_rounded),
            title: const Text('Reset password'),
            onTap: () => Navigator.pop(context, 'reset'),
          ),
          if (p.user.id != saya?.id)
            ListTile(
              leading: Icon(p.aktif ? Icons.person_off_outlined : Icons.person_outline_rounded,
                  color: p.aktif ? AppColors.merah : AppColors.hijau),
              title: Text(p.aktif ? 'Nonaktifkan akun' : 'Aktifkan akun',
                  style: TextStyle(color: p.aktif ? AppColors.merah : AppColors.hijau)),
              onTap: () => Navigator.pop(context, 'status'),
            ),
        ]),
      ),
    );
    if (aksi == null || !mounted) return;
    final repo = ref.read(adminRepositoryProvider);

    try {
      switch (aksi) {
        case 'ubah':
          await _form(p);
          return;
        case 'foto':
          final pilihan = await pilihFotoProfil(context, adaFoto: p.user.fotoUrl != null);
          if (pilihan == null) return;
          switch (pilihan) {
            case FotoBaru(:final file):
              await repo.gantiFoto(p.user.id, file);
            case HapusFoto():
              await repo.hapusFoto(p.user.id);
          }
          if (mounted) showPesan(context, 'Foto ${p.user.name} diperbarui.');
          // Jika admin mengganti fotonya sendiri, perbarui juga di beranda/profil
          if (p.user.id == saya?.id) await ref.read(authControllerProvider.notifier).refreshUser();
          setState(() => _versi++);
        case 'reset':
          final pass = await mintaTeks(
            context,
            judul: 'Reset password',
            isi: 'Password ${p.user.name} akan diganti dan akunnya keluar dari semua perangkat.',
            label: 'Password baru',
            helper: 'Minimal 6 karakter. Sampaikan ke pengurus yang bersangkutan.',
            ya: 'Reset',
          );
          if (pass == null) return;
          if (pass.length < 6) {
            if (mounted) showPesan(context, 'Password minimal 6 karakter.', error: true);
            return;
          }
          await repo.resetPassword(p.user.id, pass);
          if (mounted) showPesan(context, 'Password ${p.user.name} berhasil direset.');
        case 'status':
          final ok = await konfirmasi(
            context,
            judul: p.aktif ? 'Nonaktifkan akun?' : 'Aktifkan akun?',
            isi: p.aktif
                ? '${p.user.name} tidak bisa login lagi. Riwayat transaksi yang pernah dicatatnya tetap tersimpan.'
                : '${p.user.name} bisa login kembali.',
            ya: p.aktif ? 'Nonaktifkan' : 'Aktifkan',
            bahaya: p.aktif,
          );
          if (!ok) return;
          if (p.aktif) {
            await repo.nonaktifkan(p.user.id);
          } else {
            await repo.simpanPengurus(
              id: p.user.id,
              name: p.user.name,
              username: p.user.username,
              role: p.user.role.name,
              gender: p.user.gender,
              phone: p.user.phone,
              aktif: true,
            );
          }
          if (mounted) showPesan(context, p.aktif ? 'Akun dinonaktifkan.' : 'Akun diaktifkan.');
          setState(() => _versi++);
      }
    } on ApiException catch (e) {
      if (mounted) showPesan(context, e.errors.values.firstOrNull?.first ?? e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(adminRepositoryProvider);

    Widget chip(String label, String? nilai) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label),
            selected: _role == nilai,
            showCheckmark: false,
            selectedColor: AppColors.hijau,
            labelStyle: TextStyle(color: _role == nilai ? Colors.white : AppColors.teks, fontWeight: FontWeight.w600),
            onSelected: (_) => setState(() => _role = nilai),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Pengurus')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _form,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Pengurus'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _cari,
              decoration: const InputDecoration(hintText: 'Cari nama atau username', prefixIcon: Icon(Icons.search_rounded)),
              onChanged: (v) {
                _jeda?.cancel();
                _jeda = Timer(const Duration(milliseconds: 450), () => setState(() => _kata = v.trim()));
              },
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                chip('Semua', null),
                chip('Admin', 'admin'),
                chip('Ketua', 'ketua'),
                chip('Sekretaris', 'sekretaris'),
                chip('Bendahara', 'bendahara'),
              ],
            ),
          ),
          Expanded(
            child: PagedList<Pengurus>(
              reloadKey: '$_kata|$_role|$_versi',
              muat: (page) => repo.pengurus(page: page, role: _role, search: _kata),
              itemBuilder: (_, p) => _PengurusTile(
                pengurus: p,
                headers: ref.read(apiClientProvider).authHeaders,
                onTap: () => _aksi(p),
              ),
              kosong: const EmptyView(icon: Icons.badge_outlined, judul: 'Belum ada pengurus'),
              separator: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class _PengurusTile extends StatelessWidget {
  const _PengurusTile({required this.pengurus, required this.headers, required this.onTap});

  final Pengurus pengurus;
  final Map<String, String> headers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final u = pengurus.user;
    final text = Theme.of(context).textTheme;

    return Opacity(
      opacity: pengurus.aktif ? 1 : 0.55,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                UserAvatar(inisial: u.inisial, fotoUrl: u.fotoUrl, headers: headers, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.name, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      Text(
                        '@${u.username} · ${u.role.label}${pengurus.aktif ? '' : ' · nonaktif'}',
                        style: text.bodySmall?.copyWith(color: AppColors.teks2),
                      ),
                    ],
                  ),
                ),
                if (u.gender != null && !u.isAdmin) GenderPill(u.gender!) else const Pill(label: 'Putra & Putri'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PengurusForm extends ConsumerStatefulWidget {
  const _PengurusForm({this.pengurus});

  final Pengurus? pengurus;

  @override
  ConsumerState<_PengurusForm> createState() => _PengurusFormState();
}

class _PengurusFormState extends ConsumerState<_PengurusForm> {
  final _form = GlobalKey<FormState>();
  late final _nama = TextEditingController(text: widget.pengurus?.user.name);
  late final _username = TextEditingController(text: widget.pengurus?.user.username);
  late final _phone = TextEditingController(text: widget.pengurus?.user.phone);
  final _password = TextEditingController();
  late String _role = widget.pengurus?.user.role.name ?? 'sekretaris';
  late String? _gender = widget.pengurus?.user.gender;
  bool _loading = false;
  Map<String, List<String>> _errors = const {};

  bool get _baru => widget.pengurus == null;

  @override
  void dispose() {
    _nama.dispose();
    _username.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    setState(() => _errors = const {});
    if (!_form.currentState!.validate()) return;
    if (_role != 'admin' && _gender == null) {
      showPesan(context, 'Pilih bagian putra atau putri.', error: true);
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(adminRepositoryProvider).simpanPengurus(
            id: widget.pengurus?.user.id,
            name: _nama.text.trim(),
            username: _username.text.trim(),
            password: _password.text,
            role: _role,
            gender: _gender,
            phone: _phone.text.trim(),
          );
      if (!mounted) return;
      showPesan(context, _baru ? 'Akun pengurus dibuat.' : 'Data pengurus disimpan.');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errors = e.errors);
      _form.currentState!.validate();
      if (e.errors.isEmpty) showPesan(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saya = ref.watch(authControllerProvider).value;
    final diriSendiri = widget.pengurus?.user.id == saya?.id;

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Peran', prefixIcon: Icon(Icons.shield_outlined)),
            items: [
              for (final r in [Role.ketua, Role.sekretaris, Role.bendahara, Role.admin])
                DropdownMenuItem(value: r.name, child: Text(r.label)),
            ],
            // Admin tidak boleh mengubah perannya sendiri
            onChanged: diriSendiri ? null : (r) => setState(() => _role = r ?? _role),
          ),
          const SizedBox(height: 14),
          if (_role != 'admin') ...[
            Text('Bagian', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            PilihGender(value: _gender, onChanged: (g) => setState(() => _gender = g)),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: _nama,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nama lengkap', prefixIcon: Icon(Icons.person_outline_rounded)),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi.' : _errors['name']?.first,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _username,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Username',
              helperText: 'Huruf, angka, tanda hubung, garis bawah. Dipakai untuk login.',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Username wajib diisi.' : _errors['username']?.first,
          ),
          const SizedBox(height: 14),
          if (_baru) ...[
            TextFormField(
              controller: _password,
              decoration: const InputDecoration(labelText: 'Password awal', prefixIcon: Icon(Icons.lock_outline_rounded)),
              validator: (v) => (v == null || v.length < 6) ? 'Password minimal 6 karakter.' : _errors['password']?.first,
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'No. telepon (opsional)', prefixIcon: Icon(Icons.phone_outlined)),
          ),
          const SizedBox(height: 20),
          TombolSimpan(loading: _loading, onPressed: _simpan, label: _baru ? 'Buat akun' : 'Simpan'),
        ],
      ),
    );
  }
}
