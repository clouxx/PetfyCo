import 'package:flutter/material.dart';

class AppColors {
  static const Color blue = Color(0xFF4FC3F7);
  static const Color orange = Color(0xFFFF9800);
  static const Color pink = Color(0xFFEC407A);
  static const Color green = Color(0xFF4CAF50);
  static const Color navy = Color(0xFF0D1C2E);
  static const Color white = Colors.white;
}

class AppTheme {
  static ThemeData get light => _buildPetfyTheme();
}

ThemeData _buildPetfyTheme() {
  final base = ThemeData.light(useMaterial3: true);

  return base.copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      primary: AppColors.blue,
      secondary: AppColors.orange,
      tertiary: AppColors.pink,
      surface: AppColors.white,
      onSurface: AppColors.navy,
      onPrimary: AppColors.navy,
      onSecondary: AppColors.white,
    ),
    scaffoldBackgroundColor: AppColors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.navy,
      centerTitle: true,
      elevation: 0,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.navy,
      displayColor: AppColors.navy,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.orange,
        foregroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      labelStyle: const TextStyle(color: AppColors.navy),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.blue.withValues(alpha: .06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    cardTheme: CardTheme(
      color: AppColors.white,
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: const EdgeInsets.all(10),
    ),
  );
}
