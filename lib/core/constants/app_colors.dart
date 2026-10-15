import 'package:flutter/material.dart';

/// FeesVault premium design system — deep indigo brand with warm surface tones.
/// Feels authoritative, trustworthy, and distinctly non-generic.
class AppColors {
  AppColors._();

  // ── Brand / Accent ─────────────────────────────────────────────────────────
  /// Deep indigo — primary buttons, active nav, key highlights
  static const Color brand = Color(0xFF4F46E5); // Indigo 600
  static const Color brandDark = Color(0xFF4338CA); // Indigo 700
  static const Color brandLight = Color(0xFFEEF2FF); // Indigo 50
  static const Color brandMid = Color(0xFFC7D2FE); // Indigo 200

  // Keep teal aliases so old code doesn't break
  static const Color primaryTeal = brand;
  static const Color primaryTealDark = brandDark;
  static const Color primaryTealLight = brandLight;

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textTertiary = Color(0xFF94A3B8); // Slate 400
  static const Color textOnDark = Color(0xFFFFFFFF);

  // Keep legacy aliases
  static const Color navyDark = textPrimary;
  static const Color navy = Color(0xFF1E293B);
  static const Color slate = textSecondary;
  static const Color slateLight = textTertiary;

  // ── Backgrounds & Surfaces ────────────────────────────────────────────────
  static const Color background = Color(
    0xFFF8F9FE,
  ); // Very slightly lavender-tinted
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF1F5F9); // Slate 100
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE2E8F0); // Slate 200

  // ── Status: Collected / Settled ───────────────────────────────────────────
  static const Color settledGreen = Color(0xFF16A34A); // Green 600
  static const Color settledGreenDark = Color(0xFF15803D); // Green 700
  static const Color settledGreenBg = Color(0xFFF0FDF4); // Green 50

  // ── Status: Partial ───────────────────────────────────────────────────────
  static const Color partialBlue = Color(0xFF0369A1);
  static const Color partialBlueBg = Color(0xFFEFF6FF);

  // ── Status: Overdue ───────────────────────────────────────────────────────
  static const Color overdueRed = Color(0xFFDC2626); // Red 600
  static const Color overdueRedDark = Color(0xFFB91C1C); // Red 700
  static const Color overdueRedBg = Color(0xFFFFF1F2); // Red 50

  // ── Status: Unpaid / Outstanding ─────────────────────────────────────────
  static const Color unpaidAmber = Color(0xFFD97706); // Amber 600
  static const Color unpaidAmberBg = Color(0xFFFFFBEB); // Amber 50

  // ── Status: Archived ─────────────────────────────────────────────────────
  static const Color archivedGray = Color(0xFF64748B);
  static const Color archivedGrayBg = Color(0xFFF1F5F9);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient overdueGradient = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
  );
}
