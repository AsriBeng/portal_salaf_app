import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final _format = NumberFormat.decimalPattern('id_ID');

/// Memformat angka saat diketik: 150000 → 150.000
class RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();

    final teks = _format.format(int.parse(digits));
    return TextEditingValue(text: teks, selection: TextSelection.collapsed(offset: teks.length));
  }
}

/// "150.000" → 150000 (null jika kosong)
int? bacaRupiah(String teks) {
  final digits = teks.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? null : int.parse(digits);
}

/// 150000 → "150.000"
String tulisRupiah(int? nilai) => nilai == null ? '' : _format.format(nilai);
