import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/kartu.dart';

/// Membuat PDF kartu santri seukuran KTP (85,6 × 54 mm), siap cetak.
/// Tata letaknya sama dengan [KartuSantriView] (desain 428 × 270 satuan).
Future<Uint8List> buatPdfKartu(KartuSantri kartu, {Uint8List? foto}) async {
  final logo = pw.MemoryImage((await rootBundle.load('assets/images/logo.png')).buffer.asUint8List());
  final fotoImg = foto == null || foto.isEmpty ? null : pw.MemoryImage(foto);

  const hijau = PdfColor.fromInt(0xFF0B6B3A);
  const hijauTua = PdfColor.fromInt(0xFF064E2A);
  const hijauMuda = PdfColor.fromInt(0xFFE8F5EE);
  const emas = PdfColor.fromInt(0xFFF2C300);
  const teks = PdfColor.fromInt(0xFF14231B);
  const teks2 = PdfColor.fromInt(0xFF5B6B62);
  const merah = PdfColor.fromInt(0xFFC62828);
  // Warna pola: hijau yang sudah dicampur putih (setara transparansi 7%)
  const pola = PdfColor.fromInt(0xFFE3EFE8);

  // 1 satuan desain = 85,6 mm / 428 = 0,2 mm
  const s = 0.2 * PdfPageFormat.mm;
  const tinggiKepala = 62 * s;
  final format = PdfPageFormat(85.6 * PdfPageFormat.mm, 54 * PdfPageFormat.mm);
  final putri = kartu.jenisKelamin == 'P';

  pw.Widget baris(String label, String nilai, {bool tebal = false, int maxLines = 1}) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3 * s),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(width: 40 * s, child: pw.Text(label, style: pw.TextStyle(fontSize: 9 * s, color: teks2))),
            pw.Expanded(
              child: pw.Text(
                nilai,
                maxLines: maxLines,
                overflow: pw.TextOverflow.clip,
                style: pw.TextStyle(
                  fontSize: (tebal ? 11 : 9) * s,
                  color: teks,
                  fontWeight: tebal ? pw.FontWeight.bold : pw.FontWeight.normal,
                  letterSpacing: tebal ? 0.5 * s : 0,
                  lineSpacing: 1 * s,
                ),
              ),
            ),
          ],
        ),
      );

  final doc = pw.Document(title: 'Kartu Santri ${kartu.nis}', author: kartu.pondokNama);

  doc.addPage(
    pw.Page(
      pageFormat: format,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Stack(
        children: [
          // Latar badan: gradasi lembut
          pw.Positioned.fill(
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                gradient: pw.LinearGradient(
                  begin: pw.Alignment.topLeft,
                  end: pw.Alignment.bottomRight,
                  colors: [PdfColors.white, PdfColor.fromInt(0xFFF3FAF6), PdfColor.fromInt(0xFFFFFBEA)],
                ),
              ),
            ),
          ),
          // Pola bintang segi delapan
          pw.Positioned.fill(
            child: pw.CustomPaint(
              painter: (canvas, size) {
                const jarak = 34 * s;
                const r = 9 * s;
                canvas
                  ..setStrokeColor(pola)
                  ..setLineWidth(0.9 * s);
                var baris = 0;
                for (var y = size.y; y > -jarak; y -= jarak, baris++) {
                  final geser = baris.isOdd ? jarak / 2 : 0.0;
                  for (var x = -jarak; x < size.x + jarak; x += jarak) {
                    for (final sudutAwal in [0.0, math.pi / 4]) {
                      for (var i = 0; i < 4; i++) {
                        final a = sudutAwal + i * math.pi / 2 + math.pi / 4;
                        final px = x + geser + math.cos(a) * r;
                        final py = y + math.sin(a) * r;
                        i == 0 ? canvas.moveTo(px, py) : canvas.lineTo(px, py);
                      }
                      canvas
                        ..closePath()
                        ..strokePath();
                    }
                  }
                }
              },
            ),
          ),
          // Logo samar di belakang data
          pw.Positioned(
            right: 96 * s,
            top: tinggiKepala + 24 * s,
            child: pw.Opacity(opacity: 0.07, child: pw.Image(logo, width: 170 * s, height: 170 * s)),
          ),
          pw.Column(
            children: [
              // Kepala
              pw.Container(
                height: tinggiKepala,
                padding: const pw.EdgeInsets.symmetric(horizontal: 14 * s),
                decoration: const pw.BoxDecoration(
                  gradient: pw.LinearGradient(colors: [hijau, hijauTua], begin: pw.Alignment.topLeft, end: pw.Alignment.bottomRight),
                ),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 44 * s,
                      height: 44 * s,
                      padding: const pw.EdgeInsets.all(3 * s),
                      decoration: const pw.BoxDecoration(color: PdfColors.white, shape: pw.BoxShape.circle),
                      child: pw.Image(logo),
                    ),
                    pw.SizedBox(width: 10 * s),
                    pw.Expanded(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            kartu.pondokNama.toUpperCase(),
                            maxLines: 2,
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 10.5 * s, fontWeight: pw.FontWeight.bold, lineSpacing: 0.5 * s),
                          ),
                          pw.SizedBox(height: 2 * s),
                          pw.Text(kartu.pondokAlamat, maxLines: 1, style: pw.TextStyle(color: PdfColors.white, fontSize: 9.5 * s)),
                        ],
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8 * s, vertical: 4 * s),
                      decoration: pw.BoxDecoration(color: emas, borderRadius: pw.BorderRadius.circular(6 * s)),
                      child: pw.Text('KARTU SANTRI', style: pw.TextStyle(color: hijauTua, fontSize: 9.5 * s, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              // Badan: foto, data, QR rata tengah vertikal
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16 * s),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 86 * s,
                        height: 114 * s,
                        padding: const pw.EdgeInsets.all(3 * s),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(10 * s),
                          border: pw.Border.all(color: emas, width: 1.5 * s),
                        ),
                        child: fotoImg == null
                            ? pw.Container(
                                decoration: pw.BoxDecoration(color: hijauMuda, borderRadius: pw.BorderRadius.circular(7 * s)),
                                alignment: pw.Alignment.center,
                                child: pw.Text(
                                  kartu.namaLengkap.isEmpty ? '?' : kartu.namaLengkap[0].toUpperCase(),
                                  style: pw.TextStyle(fontSize: 34 * s, color: hijau, fontWeight: pw.FontWeight.bold),
                                ),
                              )
                            : pw.ClipRRect(
                                horizontalRadius: 7 * s,
                                verticalRadius: 7 * s,
                                child: pw.Image(fotoImg, fit: pw.BoxFit.cover),
                              ),
                      ),
                      pw.SizedBox(width: 14 * s),
                      pw.Expanded(
                        child: pw.Column(
                          mainAxisSize: pw.MainAxisSize.min,
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              kartu.namaLengkap,
                              maxLines: 2,
                              style: pw.TextStyle(fontSize: 15 * s, fontWeight: pw.FontWeight.bold, color: hijauTua),
                            ),
                            pw.SizedBox(height: 5 * s),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 7 * s, vertical: 2 * s),
                              // Radius dalam satuan PDF; harus seukuran lencana, bukan 99
                              decoration: pw.BoxDecoration(color: hijau, borderRadius: pw.BorderRadius.circular(6 * s)),
                              child: pw.Text(
                                putri ? 'SANTRI PUTRI' : 'SANTRI PUTRA',
                                style: pw.TextStyle(fontSize: 7.5 * s, color: PdfColors.white, fontWeight: pw.FontWeight.bold, letterSpacing: 0.8 * s),
                              ),
                            ),
                            pw.SizedBox(height: 8 * s),
                            baris('NIS', kartu.nis, tebal: true),
                            baris('TTL', kartu.ttl),
                            baris('Alamat', kartu.alamat, maxLines: 3),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 10 * s),
                      pw.Column(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.all(5 * s),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.white,
                              borderRadius: pw.BorderRadius.circular(10 * s),
                              border: pw.Border.all(color: const PdfColor.fromInt(0xFFC2DDCD), width: 1 * s),
                            ),
                            child: pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: kartu.qrUrl,
                              width: 82 * s,
                              height: 82 * s,
                              color: hijauTua,
                            ),
                          ),
                          pw.SizedBox(height: 5 * s),
                          pw.Text('Pindai untuk verifikasi', style: pw.TextStyle(fontSize: 7.5 * s, color: teks2)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Garis aksen bawah
              pw.Container(
                height: 5 * s,
                decoration: const pw.BoxDecoration(gradient: pw.LinearGradient(colors: [emas, hijau, hijau, emas])),
              ),
            ],
          ),
          if (!kartu.aktif)
            pw.Center(
              child: pw.Transform.rotate(
                angle: 0.25,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 18 * s, vertical: 8 * s),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: merah, width: 3 * s)),
                  child: pw.Text('TIDAK BERLAKU', style: pw.TextStyle(color: merah, fontSize: 28 * s, fontWeight: pw.FontWeight.bold)),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  return doc.save();
}
