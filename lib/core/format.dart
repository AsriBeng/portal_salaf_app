import 'package:intl/intl.dart';

final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final _angka = NumberFormat.decimalPattern('id_ID');

String rupiah(num? nilai) => _rupiah.format(nilai ?? 0);

String angka(num? nilai) => _angka.format(nilai ?? 0);

/// "12 Oktober 2026"
String tanggal(String? iso) {
  if (iso == null || iso.isEmpty) return '-';
  final date = DateTime.tryParse(iso);
  return date == null ? iso : DateFormat('d MMMM yyyy', 'id_ID').format(date.toLocal());
}

/// "Senin, 12 Okt 2026 · 14:05"
String tanggalWaktu(String? iso) {
  final date = iso == null ? null : DateTime.tryParse(iso);
  return date == null ? '-' : DateFormat('EEEE, d MMM yyyy · HH:mm', 'id_ID').format(date.toLocal());
}

/// Salam sesuai jam.
String salam() {
  final jam = DateTime.now().hour;
  if (jam < 11) return 'Selamat pagi';
  if (jam < 15) return 'Selamat siang';
  if (jam < 18) return 'Selamat sore';
  return 'Selamat malam';
}
