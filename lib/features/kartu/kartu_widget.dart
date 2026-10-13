import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme.dart';
import '../../models/kartu.dart';

/// Kartu santri digital dengan perbandingan ukuran KTP (85,6 × 54 mm).
///
/// Digambar pada ukuran tetap 428 × 270 lalu diskalakan, supaya tampilannya
/// sama di semua layar dan sama dengan versi PDF ([buatPdfKartu]).
class KartuSantriView extends StatelessWidget {
  const KartuSantriView({super.key, required this.kartu, this.headers = const {}});

  final KartuSantri kartu;
  final Map<String, String> headers;

  static const lebar = 428.0;
  static const tinggi = 270.0;
  static const tinggiKepala = 62.0;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: lebar / tinggi,
      child: FittedBox(
        child: Container(
          width: lebar,
          height: tinggi,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Stack(
            children: [
              // Latar badan kartu: gradasi lembut + pola bintang + logo samar
              const Positioned.fill(
                top: tinggiKepala,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFFFFF), Color(0xFFF3FAF6), Color(0xFFFFFBEA)],
                    ),
                  ),
                  child: CustomPaint(painter: PolaBintangPainter()),
                ),
              ),
              Positioned(
                right: 78,
                top: tinggiKepala + 24,
                child: Opacity(
                  opacity: 0.07,
                  child: Image.asset('assets/images/logo.png', width: 170, height: 170),
                ),
              ),
              Column(
                children: [
                  _Kepala(kartu: kartu),
                  Expanded(child: _Badan(kartu: kartu, headers: headers)),
                  // Garis aksen bawah: hijau dengan sisi emas
                  Container(
                    height: 5,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.emas, AppColors.hijau, AppColors.hijau, AppColors.emas]),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pola bintang segi delapan (khatam) yang sangat samar sebagai latar kartu.
class PolaBintangPainter extends CustomPainter {
  const PolaBintangPainter();

  static const jarak = 34.0;

  @override
  void paint(Canvas canvas, Size size) {
    final garis = Paint()
      ..color = AppColors.hijau.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    for (var y = 0.0; y < size.height + jarak; y += jarak) {
      final geser = ((y / jarak).round().isOdd) ? jarak / 2 : 0.0;
      for (var x = -jarak; x < size.width + jarak; x += jarak) {
        _bintang(canvas, Offset(x + geser, y), 9, garis);
      }
    }
  }

  /// Dua persegi yang saling diputar 45° membentuk bintang delapan.
  static void _bintang(Canvas canvas, Offset c, double r, Paint paint) {
    for (final sudutAwal in [0.0, math.pi / 4]) {
      final path = Path();
      for (var i = 0; i < 4; i++) {
        final a = sudutAwal + i * math.pi / 2 + math.pi / 4;
        final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Kepala extends StatelessWidget {
  const _Kepala({required this.kartu});

  final KartuSantri kartu;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: KartuSantriView.tinggiKepala,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(gradient: AppColors.gradien),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Image.asset('assets/images/logo.png'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kartu.pondokNama.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.2, height: 1.15),
                ),
                const SizedBox(height: 2),
                Text(
                  kartu.pondokAlamat,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 9.5),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AppColors.emas, borderRadius: BorderRadius.circular(6)),
            child: const Text(
              'KARTU SANTRI',
              style: TextStyle(color: AppColors.hijauTua, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badan extends StatelessWidget {
  const _Badan({required this.kartu, required this.headers});

  final KartuSantri kartu;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    final inisial = kartu.namaLengkap.trim().isEmpty ? '?' : kartu.namaLengkap.trim()[0].toUpperCase();
    final putri = kartu.jenisKelamin == 'P';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        // Foto, data, dan QR rata tengah secara vertikal
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Foto 3x4 dengan bingkai putih dan garis emas
          Container(
            width: 110,
            height: 146,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.emas, width: 1.5),
              boxShadow: [BoxShadow(color: AppColors.hijauTua.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: kartu.fotoUrl == null
                  ? Container(
                      color: AppColors.hijauMuda,
                      alignment: Alignment.center,
                      child: Text(inisial, style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: AppColors.hijau)),
                    )
                  : Image.network(kartu.fotoUrl!, headers: headers, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kartu.namaLengkap,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.hijauTua, height: 1.2),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.hijau, borderRadius: BorderRadius.circular(99)),
                  child: Text(
                    putri ? 'SANTRI PUTRI' : 'SANTRI PUTRA',
                    style: const TextStyle(fontSize: 7.5, color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                  ),
                ),
                const SizedBox(height: 8),
                _Baris(label: 'NIS', nilai: kartu.nis, tebal: true),
                _Baris(label: 'TTL', nilai: kartu.ttl),
                _Baris(label: 'Alamat', nilai: kartu.alamat, baris: 3),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.hijau.withValues(alpha: 0.25)),
                  boxShadow: [BoxShadow(color: AppColors.hijauTua.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: QrImageView(
                  data: kartu.qrUrl,
                  size: 62,
                  padding: EdgeInsets.zero,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.hijauTua),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.hijauTua),
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Pindai untuk verifikasi',
                style: TextStyle(fontSize: 7.5, color: AppColors.teks2, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Baris extends StatelessWidget {
  const _Baris({required this.label, required this.nilai, this.tebal = false, this.baris = 1});

  final String label;
  final String nilai;
  final bool tebal;
  final int baris;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Text(label, style: const TextStyle(fontSize: 9, color: AppColors.teks2, fontWeight: FontWeight.w600, height: 1.35)),
          ),
          Expanded(
            child: Text(
              nilai,
              maxLines: baris,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: tebal ? 11 : 9,
                color: AppColors.teks,
                fontWeight: tebal ? FontWeight.w800 : FontWeight.w600,
                height: tebal ? 1.15 : 1.35,
                letterSpacing: tebal ? 0.5 : 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
