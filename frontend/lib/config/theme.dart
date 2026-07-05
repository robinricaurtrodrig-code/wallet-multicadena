import 'package:flutter/material.dart';

class AppTheme {
  // Colores principales de la marca
  static const Color primary = Color(0xFF6C5CE7);   // Purple principal (botones, acentos)
  static const Color secondary = Color(0xFF00CEC9);  // Teal secundario
  static const Color accent = Color(0xFFFD79A8);     // Rosa para detalles

  // Colores de fondo para modo oscuro
  static const Color surfaceDark = Color(0xFF1E1E2E);      // Fondo principal oscuro
  static const Color cardDark = Color(0xFF2D2D3F);         // Fondo de tarjetas oscuro

  // Colores de fondo para modo claro
  static const Color surfaceLight = Color(0xFFF8F9FA);     // Fondo principal claro
  static const Color cardLight = Color(0xFFFFFFFF);        // Fondo de tarjetas claro

  // Colores semanticos
  static const Color error = Color(0xFFFF6B6B);            // Mensajes de error
  static const Color success = Color(0xFF51CF66);          // Operaciones exitosas
  static const Color warning = Color(0xFFFFD43B);          // Advertencias

  // Colores de texto para modo claro
  static const Color textPrimary = Color(0xFF2D3436);      // Texto principal claro
  static const Color textSecondary = Color(0xFF636E72);    // Texto secundario claro

  // Colores de texto para modo oscuro
  static const Color textDark = Color(0xFFDFE6E9);         // Texto principal oscuro
  static const Color textDarkSecondary = Color(0xFFB2BEC3); // Texto secundario oscuro

  /// Tema oscuro completo con diseño Material 3
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surfaceDark,
        error: error,
      ),
      scaffoldBackgroundColor: surfaceDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceDark,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        labelStyle: const TextStyle(color: textDarkSecondary),
        hintStyle: const TextStyle(color: textDarkSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: textDark, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: textDark, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: textDark),
        bodyMedium: TextStyle(color: textDarkSecondary),
      ),
    );
  }

  /// Tema claro completo con diseño Material 3
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: surfaceLight,
        error: error,
      ),
      scaffoldBackgroundColor: surfaceLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceLight,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textSecondary),
      ),
    );
  }
}
