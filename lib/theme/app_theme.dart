import 'package:flutter/material.dart';

class AppColors {
  // ── Colores originales PetfyCo ──────────────────────────────────────
  static const navy   = Color(0xFF0E2A47);    // Texto principal / AppBar
  static const blue   = Color(0xFF56C4F2);    // Acento azul / botones
  static const orange = Color(0xFFFF8A34);    // Acento naranja / badges
  static const pink   = Color(0xFFE46AA3);    // Perdidos / mascota femenina
  static const white  = Colors.white;
  static const grey   = Color(0xFFF3F6F9);    // Fondo tarjetas
  static const bgLight = Color(0xFFF0F4FF);   // Fondo principal (lavanda suave)

  // ── Morado principal (Phase 2: Tienda, Adoptar, ModalesNuevos) ──────
  static const purple = Color(0xFF6B4BB4);    // Morado PetfyCo original

  // ── Transparencias ──────────────────────────────────────────────────
  static Color get blueGlass   => blue.withOpacity(0.12);
  static Color get navyGlass   => navy.withOpacity(0.08);
  static Color get purpleGlass => purple.withOpacity(0.10);
}

class AppTheme {
  static ThemeData get light => _buildPetfyTheme();

  static ThemeData _buildPetfyTheme() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary:   AppColors.purple,
        secondary: AppColors.orange,
        surface:   AppColors.white,
      ),
      scaffoldBackgroundColor: AppColors.bgLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.navy),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.grey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: AppColors.purple,
          foregroundColor: AppColors.white,
        ),
      ),
      textTheme: base.textTheme.copyWith(
        headlineMedium: const TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
