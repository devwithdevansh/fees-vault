import 'package:flutter/material.dart';

/// Clean, restrained iOS-oriented color palette for FeesVault.
/// Navy text & headers, light surfaces, teal accent, clear status tints.
class AppColors {
  // Primary brand & text
  static const Color navyDark = Color(0xFF0F172A); // Slate 900
  static const Color navy = Color(0xFF1E293B);     // Slate 800
  static const Color slate = Color(0xFF475569);    // Slate 600
  static const Color slateLight = Color(0xFF94A3B8);// Slate 400

  // Backgrounds & surfaces
  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF1F5F9); // Slate 100
  static const Color divider = Color(0xFFE2E8F0);       // Slate 200

  // Accent & Actions (Teal)
  static const Color primaryTeal = Color(0xFF0D9488);    // Teal 600
  static const Color primaryTealDark = Color(0xFF0F766E);// Teal 700
  static const Color primaryTealLight = Color(0xFFCCFBF1);// Teal 100

  // Status colors
  static const Color settledGreen = Color(0xFF15803D);  // Green 700
  static const Color settledGreenBg = Color(0xFFDCFCE7);// Green 100

  static const Color partialBlue = Color(0xFF0369A1);   // Sky 700
  static const Color partialBlueBg = Color(0xFFE0F2FE);  // Sky 100

  static const Color overdueRed = Color(0xFFB91C1C);     // Red 700
  static const Color overdueRedBg = Color(0xFFFEE2E2);   // Red 100

  static const Color unpaidAmber = Color(0xFFB45309);    // Amber 700
  static const Color unpaidAmberBg = Color(0xFFFEF3C7);  // Amber 100

  static const Color archivedGray = Color(0xFF64748B);   // Slate 500
  static const Color archivedGrayBg = Color(0xFFF1F5F9); // Slate 100
}
