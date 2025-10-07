import 'package:flutter/material.dart';

class AppConstants {
  static const String baseUrl = 'https://e-com-backend-x67v.onrender.com/api';
  
  // Colors
  static const Color primaryColor = Color(0xFF059669);
  static const Color primaryDark = Color(0xFF047857);
  static const Color primaryLight = Color(0xFF10B981);
  static const Color secondaryColor = Color(0xFF34D399);
  static const Color accentColor = Color(0xFF6EE7B7);
  static const Color backgroundColor = Color(0xFFF9FAFB);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color successColor = Color(0xFF10B981);
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);
  
  // Categories and Units
  static const List<String> categories = [
    'savory', 'namkeen', 'sweets', 'travel pack combo',
  ];
  
  static const List<String> units = [
    'kg', 'grams', 'pieces', 'liters', 'ml', 'dozen', 'bunches',
    'packets', 'bottles', 'cans', 'boxes', 'bags'
  ];
}
