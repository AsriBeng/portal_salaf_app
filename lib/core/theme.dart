import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Warna diambil dari logo pondok: hijau dan kuning emas.
class AppColors {
  AppColors._();

  static const hijau = Color(0xFF0B6B3A);
  static const hijauTua = Color(0xFF064E2A);
  static const hijauMuda = Color(0xFFE8F5EE);
  static const emas = Color(0xFFF2C300);
  static const emasMuda = Color(0xFFFFF8D6);
  static const merah = Color(0xFFC62828);
  static const merahMuda = Color(0xFFFDECEA);
  static const oranye = Color(0xFFB45309);
  static const oranyeMuda = Color(0xFFFFF4E5);
  static const biru = Color(0xFF1D4ED8);
  static const biruMuda = Color(0xFFE8EEFD);
  static const teks = Color(0xFF14231B);
  static const teks2 = Color(0xFF5B6B62);
  static const garis = Color(0xFFE3EBE6);
  static const latar = Color(0xFFF4F7F5);

  static const gradien = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [hijau, hijauTua],
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.hijau,
      primary: AppColors.hijau,
      secondary: AppColors.emas,
      onSecondary: AppColors.hijauTua,
      surface: Colors.white,
      error: AppColors.merah,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final text = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
      bodyColor: AppColors.teks,
      displayColor: AppColors.teks,
    );

    final radius = BorderRadius.circular(14);

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: AppColors.latar,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.latar,
        foregroundColor: AppColors.teks,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.garis),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: AppColors.garis)),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: AppColors.garis)),
        focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: AppColors.hijau, width: 1.6)),
        errorBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: AppColors.merah)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: AppColors.merah, width: 1.6)),
        prefixIconColor: AppColors.teks2,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          side: const BorderSide(color: AppColors.garis, width: 1.4),
          textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.hijauMuda,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelSmall?.copyWith(
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? AppColors.hijau : AppColors.teks2,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? AppColors.hijau : AppColors.teks2,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.garis, space: 1),
    );
  }
}
