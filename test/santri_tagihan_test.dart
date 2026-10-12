import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:portal_salaf_app/core/api_client.dart';
import 'package:portal_salaf_app/core/token_storage.dart';
import 'package:portal_salaf_app/features/auth/auth_controller.dart';
import 'package:portal_salaf_app/features/keuangan/keuangan_repository.dart';
import 'package:portal_salaf_app/features/keuangan/tagihan_pages.dart';
import 'package:portal_salaf_app/models/keuangan.dart';
import 'package:portal_salaf_app/models/user.dart';

class _AuthTetap extends AuthController {
  _AuthTetap(this.user);

  final User user;

  @override
  Future<User?> build() async => user;
}

class _RepoTiruan extends KeuanganRepository {
  _RepoTiruan({this.riwayat = const []}) : super(ApiClient(TokenStorage()));

  final List<Map<String, dynamic>> riwayat;
  final dikirim = <int>[];

  @override
  Future<Tagihan> detailTagihan(int id) async => Tagihan.fromJson({
        'id': id,
        'judul': 'SPP Oktober 2026',
        'nominal': 150000,
        'terbayar': 0,
        'sisa': 150000,
        'status': 'belum_bayar',
        'jatuh_tempo': '2026-10-10',
        'pembayaran': riwayat,
      });

  @override
  Future<String> bayar({
    required int tagihanId,
    required int nominal,
    String? metode,
    String? tanggalBayar,
    String? catatan,
    UploadFile? bukti,
  }) async {
    dikirim.add(nominal);
    return 'Bukti pembayaran terkirim.';
  }
}

const _santri = User(id: 5, name: 'Ahmad Fauzi', username: '2025001', role: Role.santri, gender: 'L', genderLabel: 'Putra');

Future<void> _pasang(WidgetTester tester, _RepoTiruan repo) async {
  final router = GoRouter(
    initialLocation: '/tagihan/1',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox()),
      GoRoute(path: '/tagihan/:id', builder: (_, s) => TagihanDetailPage(id: int.parse(s.pathParameters['id']!))),
    ],
  );
  await tester.binding.setSurfaceSize(const Size(420, 900));
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      authControllerProvider.overrideWith(() => _AuthTetap(_santri)),
      keuanganRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('Santri melihat tombol kirim bukti, bukan tombol bendahara', (tester) async {
    await _pasang(tester, _RepoTiruan());

    expect(find.text('Kirim bukti pembayaran'), findsOneWidget);
    expect(find.text('Catat pembayaran'), findsNothing);
    // Santri tidak bisa mengubah / menghapus tagihan
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });

  testWidgets('Form upload menolak kiriman tanpa bukti dan nominal melebihi sisa', (tester) async {
    final repo = _RepoTiruan();
    await _pasang(tester, repo);

    await tester.tap(find.text('Kirim bukti pembayaran'));
    await tester.pumpAndSettle();
    expect(find.text('Tambahkan bukti transfer *'), findsOneWidget);

    // Nominal melebihi sisa
    await tester.enterText(find.byType(TextFormField).first, '200000');
    await tester.tap(find.widgetWithText(FilledButton, 'Kirim bukti pembayaran').last);
    await tester.pumpAndSettle();
    expect(find.text('Maksimal Rp 150.000.'), findsOneWidget);

    // Nominal benar tapi bukti belum dilampirkan
    await tester.enterText(find.byType(TextFormField).first, '150000');
    await tester.tap(find.widgetWithText(FilledButton, 'Kirim bukti pembayaran').last);
    await tester.pumpAndSettle();
    expect(find.text('Lampirkan foto atau screenshot bukti transfer.'), findsOneWidget);
    expect(repo.dikirim, isEmpty);
  });

  testWidgets('Jika bukti masih menunggu verifikasi, santri tidak bisa mengirim lagi', (tester) async {
    await _pasang(
      tester,
      _RepoTiruan(riwayat: [
        {
          'id': 3,
          'tagihan_id': 1,
          'nominal': 150000,
          'metode': 'transfer',
          'sumber': 'santri',
          'status': 'menunggu',
          'tanggal_bayar': '2026-10-12',
        },
      ]),
    );

    expect(find.text('Kirim bukti pembayaran'), findsNothing);
    expect(find.textContaining('sedang menunggu verifikasi'), findsOneWidget);
  });
}
