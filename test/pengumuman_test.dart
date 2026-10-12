import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:portal_salaf_app/core/api_client.dart';
import 'package:portal_salaf_app/core/token_storage.dart';
import 'package:portal_salaf_app/features/auth/auth_controller.dart';
import 'package:portal_salaf_app/features/pengumuman/pengumuman_pages.dart';
import 'package:portal_salaf_app/features/pengumuman/pengumuman_repository.dart';
import 'package:portal_salaf_app/models/akses.dart';
import 'package:portal_salaf_app/models/pengumuman.dart';
import 'package:portal_salaf_app/models/user.dart';

class _AuthTetap extends AuthController {
  _AuthTetap(this.user);

  final User user;

  @override
  Future<User?> build() async => user;
}

class _RepoTiruan extends PengumumanRepository {
  _RepoTiruan() : super(ApiClient(TokenStorage()));

  final terkirim = <String>[];

  @override
  Future<Pengumuman> simpan({
    int? id,
    required String judul,
    required String isi,
    required String target,
    UploadFile? lampiran,
    bool hapusLampiran = false,
  }) async {
    terkirim.add('$target|$judul');
    return Pengumuman(id: 1, judul: judul, isi: isi, target: target, publishedAt: '2026-10-12T08:00:00');
  }
}

User _user(Role role, {String? gender, int id = 9}) =>
    User(id: id, name: 'Uji', username: 'uji', role: role, gender: gender, genderLabel: gender == 'P' ? 'Putri' : 'Putra');

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('Notifikasi membuka halaman sesuai tipenya', () {
    Notifikasi n(String tipe) => Notifikasi.fromJson({
          'id': 'abc',
          'tipe': tipe,
          'ref_id': 12,
          'judul': 'x',
          'isi': 'y',
          'dibaca': false,
          'created_at': '2026-10-12T08:00:00Z',
        });

    expect(n('pengumuman').tujuan, '/pengumuman/12');
    expect(n('tagihan').tujuan, '/tagihan/12');
    expect(n('pembayaran').tujuan, '/pembayaran/12');
    expect(n('lain').tujuan, isNull);
    expect(n('tagihan').tandaiDibaca().dibaca, isTrue);
  });

  test('Hak ubah pengumuman: pembuat atau admin', () {
    final sekretaris = _user(Role.sekretaris, gender: 'L', id: 5);
    expect(sekretaris.bisaBuatPengumuman, isTrue);
    expect(sekretaris.bisaUbahPengumuman(5), isTrue);
    expect(sekretaris.bisaUbahPengumuman(6), isFalse);
    expect(_user(Role.admin).bisaUbahPengumuman(6), isTrue);
    expect(_user(Role.bendahara, gender: 'L').bisaBuatPengumuman, isFalse);
    expect(_user(Role.santri, gender: 'L').bisaBuatPengumuman, isFalse);
  });

  Future<_RepoTiruan> pasangForm(WidgetTester tester, User user) async {
    final repo = _RepoTiruan();
    await tester.binding.setSurfaceSize(const Size(420, 900));
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authControllerProvider.overrideWith(() => _AuthTetap(user)),
        pengumumanRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/form',
          routes: [
            GoRoute(path: '/', builder: (_, _) => const Text('daftar')),
            GoRoute(path: '/form', builder: (_, _) => const PengumumanFormPage()),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('Sekretaris putra hanya bisa memilih Semua atau Putra', (tester) async {
    await pasangForm(tester, _user(Role.sekretaris, gender: 'L'));

    expect(find.widgetWithText(SegmentedButton<String>, 'Semua'), findsOneWidget);
    expect(find.widgetWithText(SegmentedButton<String>, 'Putra'), findsOneWidget);
    expect(find.widgetWithText(SegmentedButton<String>, 'Putri'), findsNothing);
  });

  testWidgets('Admin bisa memilih semua sasaran dan pengumuman terkirim setelah konfirmasi', (tester) async {
    final repo = await pasangForm(tester, _user(Role.admin));
    expect(find.widgetWithText(SegmentedButton<String>, 'Putri'), findsOneWidget);

    // Judul kosong ditolak
    await tester.tap(find.widgetWithText(FilledButton, 'Kirim pengumuman'));
    await tester.pumpAndSettle();
    expect(find.text('Judul wajib diisi.'), findsOneWidget);

    await tester.tap(find.text('Putri'));
    await tester.enterText(find.byType(TextFormField).at(0), 'Ro\'an Jumat');
    await tester.enterText(find.byType(TextFormField).at(1), 'Kerja bakti bersama pukul 07.00.');
    await tester.tap(find.widgetWithText(FilledButton, 'Kirim pengumuman'));
    await tester.pumpAndSettle();

    expect(find.text('Kirim pengumuman?'), findsOneWidget);
    expect(find.textContaining('santri putri'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Kirim'));
    await tester.pumpAndSettle();

    expect(repo.terkirim, ["putri|Ro'an Jumat"]);
    // Form dibuka langsung (tanpa halaman sebelumnya): setelah terkirim aman kembali ke beranda
    expect(find.text('daftar'), findsOneWidget);
  });
}
