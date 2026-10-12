import 'package:flutter_test/flutter_test.dart';
import 'package:portal_salaf_app/core/api_client.dart';
import 'package:portal_salaf_app/models/user.dart';

void main() {
  test('User.fromJson membaca data santri dan jabatan', () {
    final user = User.fromJson({
      'id': 1,
      'name': 'Ahmad Fauzi',
      'username': '20260001',
      'role': 'santri',
      'gender': 'L',
      'gender_label': 'Putra',
      'santri': {
        'id': 7,
        'nis': '20260001',
        'nama_lengkap': 'Ahmad Fauzi',
        'jenis_kelamin': 'L',
        'status': 'aktif',
        'kamar': {
          'nama': 'Kamar 3',
          'komplek': {'nama': 'Komplek Al-Ikhlas'},
        },
      },
    });

    expect(user.isSantri, isTrue);
    expect(user.jabatan, 'Santri Putra');
    expect(user.inisial, 'AF');
    expect(user.santri?.kamar, 'Kamar 3');
    expect(user.santri?.komplek, 'Komplek Al-Ikhlas');
  });

  test('Admin tidak menampilkan bagian putra/putri', () {
    final user = User.fromJson({'id': 1, 'name': 'Admin', 'username': 'admin', 'role': 'admin'});
    expect(user.jabatan, 'Admin / Pengasuh');
    expect(User.fromJson({'id': 2, 'name': 'Admin / Pengasuh', 'username': 'a', 'role': 'admin'}).inisial, 'AP');
  });

  test('ApiException membaca error validasi', () {
    final e = ApiException('Data tidak valid', statusCode: 422, errors: {
      'password': ['Password minimal 6 karakter.'],
    });
    expect(e.fieldError('password'), 'Password minimal 6 karakter.');
    expect(e.fieldError('nis'), isNull);
  });
}
