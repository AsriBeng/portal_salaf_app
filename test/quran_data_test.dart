import 'package:flutter_test/flutter_test.dart';
import 'package:portal_salaf_app/features/buku_saku/quran_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Data Al-Qur\'an lengkap dan pembagian halaman & juz benar', () async {
    final q = await QuranData.muat();

    expect(q.surat, hasLength(114));
    expect(q.surat.fold(0, (n, s) => n + s.jumlahAyat), QuranData.jumlahAyat);
    expect(q.basmalah, startsWith('بِسْمِ'));
    expect(q.arab(2, 1), isNot(contains('بِسْمِ')));

    // halaman 1 = Al-Fatihah, halaman 2 dimulai Al-Baqarah 1
    expect(q.rentangHalaman(1), (q.indeks(1, 1), q.indeks(2, 1)));
    expect(q.halaman(q.indeks(2, 5)), 2);
    expect(q.halaman(q.indeks(114, 6)), 604);

    // juz 2 dimulai Al-Baqarah 142 di halaman 22; juz 30 dimulai An-Naba'
    expect(q.juz(q.indeks(2, 141)), 1);
    expect(q.juz(q.indeks(2, 142)), 2);
    expect(q.halaman(q.indeks(2, 142)), 22);
    expect(q.ayat(q.rentangJuz(30).$1).surat, 78);
    expect(q.rentangSurat(114).$2, QuranData.jumlahAyat);
  });

  test('Angka Arab', () => expect(angkaArab(286), '٢٨٦'));
}
