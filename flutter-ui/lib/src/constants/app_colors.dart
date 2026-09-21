import 'package:flutter/material.dart';

class AppColors {
  // Primary colors - Минималистичная черно-бело-серая палитра
  static const Color primary = Color(0xFF000000);        // Pure Black
  static const Color primaryVariant = Color(0xFF1F2937); // Dark Gray
  static const Color accent = Color(0xFF6B7280);         // Medium Gray
  static const Color background = Color(0xFFFAFAFA);     // Off White
  static const Color surface = Color(0xFFFFFFFF);        // Pure White
  static const Color error = Color(0xFFDC2626);          // Red for errors

  // Text colors
  static const Color textPrimary = Color(0xFF000000);    // Black for primary text
  static const Color textSecondary = Color(0xFF6B7280);  // Gray for secondary text
  static const Color textHint = Color(0xFF9CA3AF);       // Light Gray for hints

  // Borders and dividers
  static const Color divider = Color(0xFFE5E7EB);        // Light Gray
  static const Color border = Color(0xFFD1D5DB);         // Medium Gray

  // States
  static const Color disabled = Color(0xFFD1D5DB);       // Gray for inactive
  static const Color selected = Color(0xFFF3F4F6);       // Very Light Gray for selected
  static const Color hover = Color(0xFFF9FAFB);          // Ultra Light Gray for hover

  // Financial status colors
  static const Color success = Color(0xFF00A673);        // Green for positive
  static const Color warning = Color(0xFFF59E0B);        // Amber for warnings
  static const Color danger = Color(0xFFDC2626);         // Red for negative
  static const Color info = Color(0xFF3B82F6);           // Blue for information

  // Monochrome variations
  static const Color black = Color(0xFF000000);          // Pure Black
  static const Color darkGray = Color(0xFF1F2937);       // Dark Gray
  static const Color mediumGray = Color(0xFF6B7280);     // Medium Gray
  static const Color lightGray = Color(0xFFD1D5DB);      // Light Gray
  static const Color veryLightGray = Color(0xFFF3F4F6);  // Very Light Gray
  static const Color white = Color(0xFFFFFFFF);          // Pure White

  // Card and elevation colors
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color cardShadow = Color(0x1A000000);     // Black shadow

  // Web-specific colors
  static const Color webBackground = Color(0xFFFAFAFA);
  static const Color webSurface = Color(0xFFFFFFFF);
  static const Color webBorder = Color(0xFFE5E7EB);

  // Dark theme colors
  static const Color darkPrimary = Color(0xFFFFFFFF);    // White for dark theme
  static const Color darkBackground = Color(0xFF000000); // Black background
  static const Color darkSurface = Color(0xFF1F2937);    // Dark Gray surface
  static const Color darkTextPrimary = Color(0xFFFFFFFF); // White text
  static const Color darkTextSecondary = Color(0xFFD1D5DB); // Light Gray secondary text

  // Gradient colors
  static const Color gradientStart = Color(0xFF000000);  // Black
  static const Color gradientEnd = Color(0xFF6B7280);    // Gray
  static const Color gradientAccent = Color(0xFF1F2937); // Dark Gray

  // Budget categories colors - Монохромная палитра
  static const Color food = Color(0xFF374151);           // Dark Gray for food
  static const Color transport = Color(0xFF6B7280);      // Medium Gray for transport
  static const Color entertainment = Color(0xFF9CA3AF);  // Light Gray for entertainment
  static const Color shopping = Color(0xFFD1D5DB);       // Very Light Gray for shopping
  static const Color health = Color(0xFF1F2937);         // Dark Gray for health
  static const Color education = Color(0xFF4B5563);      // Medium Dark Gray for education
  static const Color housing = Color(0xFF6B7280);        // Medium Gray for housing
  static const Color utilities = Color(0xFF9CA3AF);      // Light Gray for utilities

  // Income colors
  static const Color salary = Color(0xFF000000);         // Black for salary
  static const Color bonus = Color(0xFF1F2937);          // Dark Gray for bonus
  static const Color investment = Color(0xFF374151);     // Medium Dark Gray for investment
  static const Color other = Color(0xFF6B7280);          // Medium Gray for other income

  // Savings and investment colors
  static const Color savings = Color(0xFF000000);        // Black for savings
  static const Color profit = Color(0xFF1F2937);         // Dark Gray for profits
  static const Color loss = Color(0xFF6B7280);           // Medium Gray for losses
}