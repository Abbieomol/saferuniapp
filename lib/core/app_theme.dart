import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Safer Uni's visual identity in one place: colours, gradient, shadows,
/// typography and component styles, so every screen looks consistent.
class AppTheme {
  AppTheme._();

  // Brand colours
  static const Color primary = Color(0xFF0B2E59); // deep navy
  static const Color primaryLight = Color(0xFF1D4E89);
  static const Color accent = Color(0xFFE4572E); // alert orange
  static const Color background = Color(0xFFF4F6FA);
  static const Color ink = Color(0xFF14213D); // main text
  static const Color outline = Color(0xFFE3E8F0);

  /// Navy gradient used for headers (auth, home hero).
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  /// Soft navy-tinted shadow for raised cards.
  static const List<BoxShadow> softShadow = [
    BoxShadow(color: Color(0x140B2E59), blurRadius: 20, offset: Offset(0, 8)),
  ];

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: accent,
      surface: Colors.white,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final textTheme = base.textTheme.apply(
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      bodyColor: ink,
      displayColor: ink,
    );

    final rounded12 = BorderRadius.circular(12);
    final rounded14 = BorderRadius.circular(14);

    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(borderRadius: rounded14),
        enabledBorder: OutlineInputBorder(
          borderRadius: rounded14,
          borderSide: const BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: rounded14,
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
        prefixIconColor: Colors.blueGrey.shade400,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Width stays flexible so buttons also work in dialogs/rows;
          // forms stretch them to full width.
          minimumSize: const Size(64, 54),
          shape: RoundedRectangleBorder(borderRadius: rounded14),
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 50),
          shape: RoundedRectangleBorder(borderRadius: rounded14),
          side: const BorderSide(color: outline),
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        extendedTextStyle: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: outline),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: primary.withValues(alpha: 0.12),
        side: const BorderSide(color: outline),
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelLarge?.copyWith(color: ink),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: Colors.white,
          selectedBackgroundColor: primary,
          selectedForegroundColor: Colors.white,
          side: const BorderSide(color: outline),
          shape: RoundedRectangleBorder(borderRadius: rounded12),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withValues(alpha: 0.1),
        elevation: 3,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        shape: RoundedRectangleBorder(borderRadius: rounded12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      dividerTheme: const DividerThemeData(color: outline),
    );
  }
}
