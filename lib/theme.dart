import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFFFF5A1F);
  static const accent = Color(0xFFFF2D87);
  static const accent2 = Color(0xFFFFB020);
  static const bg = Color(0xFF0D0E12);
  static const card = Color(0xFF181A20);
  static const cardLight = Color(0xFF22252D);
  static const muted = Color(0xFF8A8F98);
  static const success = Color(0xFF2EE59D);
}

const rayvaGradient = LinearGradient(
  colors: [AppColors.accent2, AppColors.primary, AppColors.accent],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const routeGradientColors = [
  AppColors.accent2,
  AppColors.primary,
  AppColors.accent,
];

ThemeData buildRayvaTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
    primary: AppColors.primary,
    surface: AppColors.bg,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.primary.withValues(alpha: 0.22),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.primary,
      thumbColor: Colors.white,
      inactiveTrackColor: Colors.white24,
      trackHeight: 3,
    ),
  );
}

