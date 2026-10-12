import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_salaf_app/core/api_client.dart';
import 'package:portal_salaf_app/core/token_storage.dart';
import 'package:portal_salaf_app/features/admin/admin_repository.dart';
import 'package:portal_salaf_app/features/admin/pengurus_pages.dart';
import 'package:portal_salaf_app/features/auth/auth_controller.dart';
import 'package:portal_salaf_app/models/santri.dart';
import 'package:portal_salaf_app/models/user.dart';

class _AuthTetap extends AuthController {
  @override
  Future<User?> build() async => const User(id: 1, name: 'Admin', username: 'admin', role: Role.admin);
}

class _RepoTiruan extends AdminRepository {
  _RepoTiruan() : super(ApiClient(TokenStorage()));

  final dibuat = <String>[];

  @override
  Future<Halaman<Pengurus>> pengurus({int page = 1, String? role, String? search}) async => Halaman(
        items: [
          Pengurus.fromJson({
            'id': 2,
            'name': 'Ust. Ahmad Syaifuddin',
            'username': 'sekretaris_putra',
            'role': 'sekretaris',
            'gender': 'L',
            'gender_label': 'Putra',
            'is_active': true,
          }),
        ],
        page: 1,
        lastPage: 1,
        total: 1,
      );

  @override
  Future<void> simpanPengurus({
    int? id,
    required String name,
    required String username,
    String? password,
    required String role,
    String? gender,
    String? phone,
    bool? aktif,
  }) async =>
      dibuat.add('$role|$gender|$username');
}

void main() {
  testWidgets('Admin menambah bendahara putri; bagian wajib dipilih', (tester) async {
    final repo = _RepoTiruan();
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authControllerProvider.overrideWith(_AuthTetap.new),
        adminRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: PengurusPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Ust. Ahmad Syaifuddin'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Pilih peran bendahara
    await tester.tap(find.text('Sekretaris').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bendahara').last);
    await tester.pumpAndSettle();

    final isian = find.byType(TextFormField);
    await tester.enterText(isian.at(0), 'Ustdz. Nur Hidayah');
    await tester.enterText(isian.at(1), 'bendahara_putri');
    await tester.enterText(isian.at(2), 'rahasia123');

    // Belum memilih putra/putri
    await tester.tap(find.widgetWithText(FilledButton, 'Buat akun'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih bagian putra atau putri.'), findsOneWidget);
    expect(repo.dibuat, isEmpty);

    await tester.tap(find.text('Putri'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Buat akun'));
    await tester.pumpAndSettle();

    expect(repo.dibuat, ['bendahara|P|bendahara_putri']);
  });
}
