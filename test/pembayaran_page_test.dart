import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:portal_salaf_app/core/api_client.dart';
import 'package:portal_salaf_app/core/token_storage.dart';
import 'package:portal_salaf_app/features/auth/auth_controller.dart';
import 'package:portal_salaf_app/features/keuangan/keuangan_repository.dart';
import 'package:portal_salaf_app/features/keuangan/pembayaran_pages.dart';
import 'package:portal_salaf_app/models/keuangan.dart';
import 'package:portal_salaf_app/models/user.dart';

/// Pengguna yang sudah login, tanpa memanggil API.
class _AuthTetap extends AuthController {
  _AuthTetap(this.user);

  final User user;

  @override
  Future<User?> build() async => user;
}

/// Repository tiruan: mencatat aksi setujui/tolak.
class _RepoTiruan extends KeuanganRepository {
  _RepoTiruan() : super(ApiClient(TokenStorage()));

  final aksi = <String>[];
  var status = 'menunggu';

  @override
  Future<Pembayaran> detailPembayaran(int id) async => Pembayaran.fromJson({
        'id': id,
        'tagihan_id': 1,
        'nominal': 150000,
        'metode': 'transfer',
        'sumber': 'santri',
        'status': status,
        'tanggal_bayar': '2026-10-12',
        'tagihan': {
          'id': 1,
          'judul': 'SPP September 2026',
          'nominal': 150000,
          'terbayar': 0,
          'sisa': 150000,
          'status': 'belum_bayar',
          'santri': {'id': 1, 'nis': '2025001', 'nama_lengkap': 'Ahmad Fauzi Rahman', 'jenis_kelamin': 'L'},
        },
      });

  @override
  Future<void> setujui(int id) async {
    aksi.add('setujui $id');
    status = 'disetujui';
  }

  @override
  Future<void> tolak(int id, String alasan) async => aksi.add('tolak $id: $alasan');
}

User _user(Role role) => User(id: 9, name: 'Uji', username: 'uji', role: role, gender: 'L', genderLabel: 'Putra');

Future<void> _pasang(WidgetTester tester, Role role, _RepoTiruan repo) async {
  final router = GoRouter(
    initialLocation: '/pembayaran/4',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox()),
      GoRoute(path: '/pembayaran/:id', builder: (_, s) => PembayaranDetailPage(id: int.parse(s.pathParameters['id']!))),
    ],
  );

  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      authControllerProvider.overrideWith(() => _AuthTetap(_user(role))),
      keuanganRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('Bendahara bisa menyetujui pembayaran yang menunggu', (tester) async {
    final repo = _RepoTiruan();
    await _pasang(tester, Role.bendahara, repo);

    expect(find.text('Rp 150.000'), findsWidgets);
    expect(find.text('Ahmad Fauzi Rahman (2025001)'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Setujui'));
    await tester.pumpAndSettle();
    expect(find.text('Setujui pembayaran?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Setujui').last);
    await tester.pumpAndSettle();

    expect(repo.aksi, ['setujui 4']);
    expect(find.text('Pembayaran disetujui.'), findsOneWidget);
    // Setelah disetujui tombol aksi hilang
    expect(find.widgetWithText(OutlinedButton, 'Tolak'), findsNothing);
  });

  testWidgets('Penolakan wajib menyertakan alasan', (tester) async {
    final repo = _RepoTiruan();
    await _pasang(tester, Role.bendahara, repo);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Tolak'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Bukti tidak terbaca');
    await tester.tap(find.widgetWithText(FilledButton, 'Tolak'));
    await tester.pumpAndSettle();

    expect(repo.aksi, ['tolak 4: Bukti tidak terbaca']);
  });

  testWidgets('Ketua hanya bisa melihat, tanpa tombol setujui/tolak', (tester) async {
    await _pasang(tester, Role.ketua, _RepoTiruan());

    expect(find.text('SPP September 2026'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Setujui'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Tolak'), findsNothing);
  });
}
