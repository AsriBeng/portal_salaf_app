import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../shared/ui.dart';

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _form = GlobalKey<FormState>();
  final _lama = TextEditingController();
  final _baru = TextEditingController();
  final _ulang = TextEditingController();

  bool _loading = false;
  bool _sembunyikan = true;
  Map<String, List<String>> _serverErrors = const {};

  @override
  void dispose() {
    _lama.dispose();
    _baru.dispose();
    _ulang.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    setState(() => _serverErrors = const {});
    if (!_form.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await ref.read(apiClientProvider).put('/me/password', data: {
        'password_lama': _lama.text,
        'password': _baru.text,
        'password_confirmation': _ulang.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password berhasil diubah.'), backgroundColor: AppColors.hijau),
      );
      context.kembali();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _serverErrors = e.errors);
      _form.currentState!.validate();
      if (e.errors.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _server(String field) => _serverErrors[field]?.first;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final toggle = IconButton(
      tooltip: _sembunyikan ? 'Tampilkan password' : 'Sembunyikan password',
      icon: Icon(_sembunyikan ? Icons.visibility_outlined : Icons.visibility_off_outlined),
      onPressed: () => setState(() => _sembunyikan = !_sembunyikan),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Ubah Password')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              'Gunakan password yang mudah Anda ingat tetapi sulit ditebak orang lain. Minimal 6 karakter.',
              style: text.bodyMedium?.copyWith(color: AppColors.teks2),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _lama,
              obscureText: _sembunyikan,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Password lama',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: toggle,
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Password lama wajib diisi.' : _server('password_lama'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _baru,
              obscureText: _sembunyikan,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Password baru', prefixIcon: Icon(Icons.lock_reset_rounded)),
              validator: (v) {
                if (v == null || v.length < 6) return 'Password baru minimal 6 karakter.';
                return _server('password');
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _ulang,
              obscureText: _sembunyikan,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _simpan(),
              decoration: const InputDecoration(labelText: 'Ulangi password baru', prefixIcon: Icon(Icons.done_all_rounded)),
              validator: (v) => v != _baru.text ? 'Ulangi password tidak sama.' : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _simpan,
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Simpan password'),
            ),
            const SizedBox(height: 12),
            Text(
              'Setelah password diubah, akun Anda otomatis keluar dari perangkat lain.',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: AppColors.teks2),
            ),
          ],
        ),
      ),
    );
  }
}
