// lib/theme/app_theme.dart

import 'package:flutter/material.dart';

class AppColors {
  static const logo = Color(0xFFFFEEDA);
  static const accent = Color(0xFFFFBF80);
  static const background = Color(0xFFFFFFFF);
  static const primaryButton = Color(0xFFFF914D);
  static const buttonHover = Color(0xFFFFB380);
  static const text = Color(0xFF333333);
  static const links = Color(0xFFFFAA5E);
  static const successMessages = Color(0xFFB2D8B2);
  static const errorMessages = Color(0xFFFF6B6B);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      primaryColor: AppColors.primaryButton,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryButton,
        secondary: AppColors.accent,
        background: AppColors.background,
        error: AppColors.errorMessages,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.text),
        bodyMedium: TextStyle(color: AppColors.text),
        titleLarge: TextStyle(color: AppColors.text),
        titleMedium: TextStyle(color: AppColors.text),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryButton,
          foregroundColor: AppColors.background,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.links,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaryButton,
        foregroundColor: AppColors.background,
      ),
      tabBarTheme: const TabBarTheme(
        labelColor: AppColors.background,
        unselectedLabelColor: AppColors.background,
        indicatorColor: AppColors.background,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryButton,
        foregroundColor: AppColors.background,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.text,
        contentTextStyle: TextStyle(color: AppColors.background),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primaryButton),
        ),
        labelStyle: const TextStyle(color: AppColors.text),
      ),
      cardTheme: CardTheme(
        color: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}