import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_salaf_app/features/kartu/kartu_pdf.dart';
import 'package:portal_salaf_app/features/kartu/kartu_widget.dart';
import 'package:portal_salaf_app/models/kartu.dart';
import 'package:portal_salaf_app/models/komplek.dart';
import 'package:portal_salaf_app/models/santri.dart';

KartuSantri contohKartu({String status = 'aktif'}) => KartuSantri.fromJson({
      'pondok': {
        'nama': "Pondok Pesantren As-Salafiyyah Asy-Syafi'iyyah",
        'alamat': 'Tambakberas Barat, Jombang',
        'logo_url': 'https://contoh/logo',
      },
      'santri': {
        'id': 7,
        'nis': '20260001',
        'nama_lengkap': 'Ahmad Fauzi',
        'jenis_kelamin': 'L',
        'tempat_lahir': 'Jombang',
        'tanggal_lahir': '2012-03-15',
        'ttl': 'Jombang, 15 Maret 2012',
        'alamat': 'Dusun Krajan, Tebuireng, Kec. Diwek, Jombang, Jawa Timur',
        'foto_url': null,
      },
      'status': status,
      'berlaku': status == 'aktif' ? 'Selama aktif sebagai santri' : 'Tidak berlaku',
      'qr_url': 'https://portalsalaf.rupamedia.my.id/kartu/abc123',
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Santri.fromJson membaca kamar, dokumen, dan data lengkap', () {
    final s = Santri.fromJson({
      'id': 3,
      'nis': '20260003',
      'nama_lengkap': 'Siti Aminah',
      'jenis_kelamin': 'P',
      'jenis_kelamin_label': 'Putri',
      'tempat_lahir': 'Kediri',
      'tanggal_lahir': '2011-01-02',
      'status': 'aktif',
      'tanggal_masuk': '2025-07-01',
      'nik': '3517000000000001',
      'kamar': {'id': 1, 'komplek_id': 2, 'nama': 'Kamar 1', 'kapasitas': 10, 'komplek': {'id': 2, 'nama': 'Komplek B', 'gender': 'P'}},
      'dokumen': {'file_kk': 'https://x/kk', 'file_akta': null, 'file_ktp': null},
    });

    expect(s.putri, isTrue);
    expect(s.lengkap, isTrue);
    expect(s.kamar?.labelLengkap, 'Kamar 1 · Komplek B');
    expect(s.dokumen['file_kk'], 'https://x/kk');
    expect(s.dokumen['file_akta'], isNull);
    expect(s.field('nik'), '3517000000000001');
  });

  test('Kamar menghitung sisa dan penuh', () {
    final kamar = Kamar.fromJson({'id': 1, 'komplek_id': 1, 'nama': 'A', 'kapasitas': 4, 'terisi': 4});
    expect(kamar.penuh, isTrue);
    expect(kamar.sisa, 0);
  });

  test('Halaman membaca meta paginasi', () {
    final h = Halaman.fromJson({
      'data': [],
      'meta': {'current_page': 1, 'last_page': 3, 'total': 45},
    }, Santri.fromJson);
    expect(h.adaLagi, isTrue);
    expect(h.total, 45);
  });

  testWidgets('Kartu santri tampil normal untuk semua status (tanpa stempel)', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: KartuSantriView(kartu: contohKartu()))));
    expect(find.text('Ahmad Fauzi'), findsOneWidget);
    expect(find.text('20260001'), findsOneWidget);
    expect(find.text('TIDAK BERLAKU'), findsNothing);

    // Santri lulus / keluar: kartu tetap tampil normal tanpa stempel
    for (final status in ['lulus', 'keluar']) {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: KartuSantriView(kartu: contohKartu(status: status)))));
      expect(find.text('Ahmad Fauzi'), findsOneWidget);
      expect(find.text('TIDAK BERLAKU'), findsNothing);
    }
  });

  test('PDF kartu berukuran KTP berhasil dibuat', () async {
    final bytes = await buatPdfKartu(contohKartu());
    expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    expect(bytes.length, greaterThan(10000)); // berisi logo dan QR
  });
}
