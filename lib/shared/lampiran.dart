import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../core/api_client.dart';
import 'ui.dart';

/// Membuka file yang dilindungi login: gambar ditampilkan di dialog, PDF dibagikan / diunduh.
Future<void> bukaLampiran(BuildContext context, ApiClient api, String url, {required String judul, required String namaFile}) async {
  try {
    final bytes = await api.getBytes(url);
    if (!context.mounted) return;

    final pdf = bytes.length > 4 && String.fromCharCodes(bytes.sublist(0, 4)) == '%PDF';
    if (pdf) {
      await Printing.sharePdf(bytes: bytes, filename: '$namaFile.pdf');
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(judul, style: const TextStyle(fontWeight: FontWeight.w800)),
              trailing: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ),
            Flexible(child: InteractiveViewer(child: Image.memory(bytes))),
          ],
        ),
      ),
    );
  } on ApiException catch (e) {
    if (context.mounted) showPesan(context, e.message, error: true);
  }
}
