import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../shared/widgets.dart';
import 'auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _sembunyikan = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _masuk() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).login(_username.text, _password.text);
      // Router otomatis pindah ke beranda
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.fieldError('username') ?? e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header hijau
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: AppColors.gradien,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              padding: EdgeInsets.fromLTRB(24, MediaQuery.paddingOf(context).top + 40, 24, 64),
              child: Column(
                children: [
                  const AppLogo(size: 96),
                  const SizedBox(height: 20),
                  Text(
                    AppConfig.appName,
                    style: text.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppConfig.tagline,
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(color: AppColors.emas, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            // Form login
            Transform.translate(
              offset: const Offset(0, -36),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Card(
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                      child: Form(
                        key: _form,
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Masuk', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text(
                                'Santri masuk dengan NIS. Pengurus masuk dengan username.',
                                style: text.bodySmall?.copyWith(color: AppColors.teks2),
                              ),
                              const SizedBox(height: 20),
                              if (_error != null) ...[
                                _ErrorBanner(message: _error!),
                                const SizedBox(height: 16),
                              ],
                              TextFormField(
                                controller: _username,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username],
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: const InputDecoration(
                                  labelText: 'NIS / Username',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                ),
                                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'NIS / username wajib diisi.' : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _password,
                                focusNode: _passwordFocus,
                                obscureText: _sembunyikan,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: IconButton(
                                    tooltip: _sembunyikan ? 'Tampilkan password' : 'Sembunyikan password',
                                    icon: Icon(_sembunyikan ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                    onPressed: () => setState(() => _sembunyikan = !_sembunyikan),
                                  ),
                                ),
                                onFieldSubmitted: (_) => _masuk(),
                                validator: (v) => (v == null || v.isEmpty) ? 'Password wajib diisi.' : null,
                              ),
                              const SizedBox(height: 22),
                              FilledButton(
                                onPressed: _loading ? null : _masuk,
                                child: _loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                      )
                                    : const Text('Masuk'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              // Selebar kartu login (440) dikurangi selisih padding sampingnya
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 416),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.emasMuda,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF5E08A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.help_outline_rounded, size: 20, color: Color(0xFF6B5500)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Lupa password? Hubungi admin atau sekretaris pondok untuk mereset password Anda.',
                          style: text.bodySmall?.copyWith(color: const Color(0xFF6B5500), height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.merahMuda, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.merah, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.merah, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
