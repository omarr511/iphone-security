import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors
  static const Color bg       = Color(0xFF0D1117);
  static const Color bg2      = Color(0xFF161B22);
  static const Color bg3      = Color(0xFF21262D);
  static const Color border   = Color(0xFF30363D);
  static const Color fg       = Color(0xFFC9D1D9);
  static const Color fg2      = Color(0xFF8B949E);
  static const Color accent   = Color(0xFF58A6FF);
  static const Color green    = Color(0xFF3FB950);
  static const Color red      = Color(0xFFF85149);
  static const Color orange   = Color(0xFFE3B341);
  static const Color yellow   = Color(0xFFE3B341);
  static const Color purple   = Color(0xFFBC8CFF);

  static const Map<String, Color> severityColors = {
    'CRITICAL': red,
    'HIGH':     orange,
    'MEDIUM':   yellow,
    'INFO':     accent,
    'SAFE':     green,
  };

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: ColorScheme.dark(
      primary: accent,
      secondary: green,
      surface: bg2,
      error: red,
    ),
    textTheme: GoogleFonts.notoSansArabicTextTheme(
      const TextTheme(
        displayLarge:  TextStyle(color: fg, fontWeight: FontWeight.bold),
        headlineMedium:TextStyle(color: fg, fontWeight: FontWeight.w600),
        bodyLarge:     TextStyle(color: fg),
        bodyMedium:    TextStyle(color: fg2),
        labelSmall:    TextStyle(color: fg2, fontSize: 11),
      ),
    ),
    cardTheme: CardThemeData(
      color: bg2,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: border, width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: fg),
      titleTextStyle: TextStyle(
        color: fg, fontSize: 17, fontWeight: FontWeight.w600,
      ),
    ),
    dividerTheme: const DividerThemeData(color: border, thickness: 1),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: bg,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    ),
  );
}
