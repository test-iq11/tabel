import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const navy = Color(0xFF183B66);
  const blue = Color(0xFF2878C8);
  const green = Color(0xFF16845B);
  final scheme = ColorScheme.fromSeed(seedColor: blue, brightness: Brightness.light).copyWith(
    primary: navy, secondary: blue, tertiary: green, surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF4F7FB),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF4F7FB), foregroundColor: navy,
      surfaceTintColor: Colors.transparent, centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: navy),
    ),
    cardTheme: CardThemeData(
      color: Colors.white, elevation: 1, shadowColor: const Color(0x140D2340),
      margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: Color(0xFFDCE4EE))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: Color(0xFFDCE4EE))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: blue, width: 1.7)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      backgroundColor: navy, foregroundColor: Colors.white, minimumSize: const Size(44, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    )),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
      foregroundColor: navy, minimumSize: const Size(44, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    )),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFEAF1F8), labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: navy),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: navy),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: navy),
      bodyMedium: TextStyle(fontSize: 14, height: 1.45),
    ),
  );
}
