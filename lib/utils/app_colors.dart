import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryLight = Color(0xFF66BB6A);
  static const Color primaryDark = Color(0xFF1B5E20);

  // Secondary Colors
  static const Color secondary = Color(0xFFFF9800);
  static const Color secondaryLight = Color(0xFFFFCC02);
  static const Color secondaryDark = Color(0xFFE65100);

  // Neutral Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textTertiary = Color(0xFF9E9E9E);

  // Background Colors
  static const Color scaffoldBackground = Colors.white;
  static const Color cardBackground = Colors.white;
  static const Color inputBackground = Color(0xFFF5F5F5);

  // Border Colors
  static const Color border = Color(0xFFE0E0E0);
  static const Color borderFocus = Color(0xFF2E7D32);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF2196F3);

  // Special Colors
  static const Color discount = Color(0xFFE53935);
  static const Color rating = Color(0xFFFFC107);
  static const Color organic = Color(0xFF8BC34A);

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, secondaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Shadow Colors
  static const Color shadow = Color(0x1A000000);
  static const Color shadowDark = Color(0x33000000);
}
