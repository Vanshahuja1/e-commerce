import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Colors.redAccent;        // unified lighter red
  static const Color primaryLight = Colors.redAccent;   // keep light as redAccent
  static const Color primaryDark = Colors.redAccent;     // unified lighter red

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
  static const Color borderFocus = Colors.redAccent; // match lighter red

  // Status Colors
  static const Color success = Colors.redAccent; // show success in lighter red
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Colors.redAccent;   // lighter red for errors
  static const Color info = Color(0xFF2196F3);

  // Special Colors
  static const Color discount = Colors.redAccent; // align discounts with lighter red
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
