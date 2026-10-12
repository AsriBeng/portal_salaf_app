import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:portal_salaf_app/core/format.dart';
import 'package:portal_salaf_app/models/keuangan.dart';
import 'package:portal_salaf_app/models/santri.dart';
import 'package:portal_salaf_app/shared/rupiah_input.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('Input rupiah diberi pemisah ribuan dan bisa dibaca kembali', () {
    final f = RupiahInputFormatter();
    final hasil = f.formatEditUpdate(TextEditingValue.empty, const TextEditingValue(text: '1500000'));
    expect(hasil.text, '1.500.000');
    expect(bacaRupiah(hasil.text), 1500000);
    expect(bacaRupiah(''), isNull);
    expect(tulisRupiah(250000), '250.000');
    expect(rupiah(150000), 'Rp 150.000');
  });

  test('Tagihan membaca status, santri, dan riwayat pembayaran', () {
    final t = Tagihan.fromJson({
      'id': 1,
      'judul': 'SPP September 2026',
      'periode': '2026-09',
      'nominal': 150000,
      'terbayar': 75000,
      'sisa': 75000,
      'status': 'dicicil',
      'jatuh_tempo': '2020-01-10',
      'santri': {'id': 3, 'nis': '2025003', 'nama_lengkap': 'Iqbal', 'jenis_kelamin': 'L'},
      'pembayaran': [
        {
          'id': 9,
          'tagihan_id': 1,
          'nominal': 75000,
          'metode': 'tunai',
          'sumber': 'bendahara',
          'status': 'disetujui',
          'tanggal_bayar': '2026-09-10',
        },
      ],
    });

    expect(t.status, StatusTagihan.dicicil);
    expect(t.lunas, isFalse);
    expect(t.lewatJatuhTempo, isTrue);
    expect(t.santri?.nis, '2025003');
    expect(t.pembayaran.single.status, StatusPembayaran.disetujui);
    expect(t.pembayaran.single.metodeLabel, 'Tunai');
  });

  test('Saldo kas pengurus hanya berisi satu gender', () {
    final s = SaldoKas.fromJson({'putra': 125000, 'total': 125000});
    expect(s.putra, 125000);
    expect(s.putri, isNull);
  });

  test('Halaman membaca paginator biasa (tanpa meta)', () {
    final h = Halaman<Map<String, dynamic>>.fromJson({
      'data': [
        {'id': 1},
      ],
      'current_page': 1,
      'last_page': 2,
      'total': 21,
    }, (m) => m);
    expect(h.adaLagi, isTrue);
    expect(h.total, 21);
  });
}
