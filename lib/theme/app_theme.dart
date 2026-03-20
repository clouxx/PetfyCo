import 'package:flutter/material.dart';

class AppColors {
  // ── EXACT Original PetfyCo Colors ─────────────────────────────────────
  static const purple = Color(0xFF4CB5F9);    // Actualizado a Azul Cielo a petición (mantiene nombre 'purple' por compatibilidad)
  static const navy   = Color(0xFF2D2D2D);    // Texto principal oscuro
  static const blue   = Color(0xFF56C4F2);    // Acento azul radiante (Iconos género)
  static const orange = Color(0xFFFF9800);    // Etiquetas adopción / Alertas
  static const pink      = Color(0xFFE91E63);    // Héroe de patitas
  static const rolPurple = Color(0xFF7C3AED);    // Selección de rol en registro
  static const red    = Color(0xFFF44336);    // Alertas perdidos
  static const white  = Colors.white;
  static const greyBg = Color(0xFFF3F6F9);    // Elementos inactivos / chips
  static const bgLight = Color(0xFFF5F5F7);   // Fondo principal exacto de la web
  static const greyText = Color(0xFF757575);  // Texto secundario

  // ── Transparencias exactas de los botones de la web ────────────────
  static Color get purpleGlass => purple.withOpacity(0.12);
  static Color get blueGlass   => blue.withOpacity(0.12);
  static Color get navyGlass   => navy.withOpacity(0.08);
  static Color get greyGlass   => const Color(0xFFE0E0E0).withOpacity(0.4);
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
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.navy,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.navy),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.purple, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: const StadiumBorder(),
          backgroundColor: AppColors.purple,
          foregroundColor: AppColors.white,
          elevation: 0, // botones planos en diseño original
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.purple,
          shape: const StadiumBorder(),
        ),
      ),
      textTheme: base.textTheme.copyWith(
        headlineMedium: const TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: const TextStyle(
          color: AppColors.navy,
        )
      ),
    );
  }
}
