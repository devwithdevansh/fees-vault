import 'package:flutter/material.dart';

/// FeesVault professional design system — Notion / Linear inspired.
/// Clean light mode with deep indigo brand, strong typography hierarchy,
/// multi-layered card depth, and precise status semantics.
class AppColors {
  AppColors._();

  // ── Brand / Accent ─────────────────────────────────────────────────────────
  /// Deep indigo — primary buttons, active nav, key highlights
  static const Color brand = Color(0xFF4F46E5); // Indigo 600
  static const Color brandDark = Color(0xFF4338CA); // Indigo 700
  static const Color brandLight = Color(0xFFEEF2FF); // Indigo 50
  static const Color brandMid = Color(0xFFC7D2FE); // Indigo 200
  static const Color brandAccent = Color(0xFF6366F1); // Indigo 500

  // Keep teal aliases so old code doesn't break
  static const Color primaryTeal = brand;
  static const Color primaryTealDark = brandDark;
  static const Color primaryTealLight = brandLight;

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900 — headings
  static const Color textSecondary = Color(0xFF334155); // Slate 700 — body
  static const Color textTertiary = Color(0xFF64748B); // Slate 500 — captions
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400 — placeholders
  static const Color textOnDark = Color(0xFFFFFFFF);

  // Keep legacy aliases
  static const Color navyDark = textPrimary;
  static const Color navy = Color(0xFF1E293B);
  static const Color slate = textSecondary;
  static const Color slateLight = textTertiary;

  // ── Backgrounds & Surfaces ────────────────────────────────────────────────
  static const Color background = Color(0xFFF7F8FC); // Slightly cool white
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF1F5F9); // Slate 100
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE2E8F0); // Slate 200
  static const Color dividerStrong = Color(0xFFCBD5E1); // Slate 300

  // ── Status: Collected / Settled ───────────────────────────────────────────
  static const Color settledGreen = Color(0xFF059669); // Emerald 600
  static const Color settledGreenDark = Color(0xFF047857); // Emerald 700
  static const Color settledGreenBg = Color(0xFFECFDF5); // Emerald 50
  static const Color settledGreenMid = Color(0xFFD1FAE5); // Emerald 100

  // ── Status: Partial ───────────────────────────────────────────────────────
  static const Color partialBlue = Color(0xFF0284C7); // Sky 600
  static const Color partialBlueBg = Color(0xFFE0F2FE); // Sky 100
  static const Color partialBlueMid = Color(0xFFBAE6FD); // Sky 200

  // ── Status: Overdue ───────────────────────────────────────────────────────
  static const Color overdueRed = Color(0xFFDC2626); // Red 600
  static const Color overdueRedDark = Color(0xFFB91C1C); // Red 700
  static const Color overdueRedBg = Color(0xFFFEF2F2); // Red 50
  static const Color overdueRedMid = Color(0xFFFECACA); // Red 200

  // ── Status: Unpaid / Outstanding ─────────────────────────────────────────
  static const Color unpaidAmber = Color(0xFFD97706); // Amber 600
  static const Color unpaidAmberDark = Color(0xFFB45309); // Amber 700
  static const Color unpaidAmberBg = Color(0xFFFFFBEB); // Amber 50
  static const Color unpaidAmberMid = Color(0xFFFDE68A); // Amber 200

  // ── Status: Archived ─────────────────────────────────────────────────────
  static const Color archivedGray = Color(0xFF64748B);
  static const Color archivedGrayBg = Color(0xFFF1F5F9);

  // ── Shadows ───────────────────────────────────────────────────────────────
  /// Soft shadow for cards — looks lifted but clean
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.03),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  /// Heavier shadow for floating / elevated surfaces
  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.10),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  /// Glow shadow for primary action buttons
  static List<BoxShadow> get brandGlow => [
    BoxShadow(
      color: brand.withValues(alpha: 0.35),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Hero header — deep indigo with a subtle blue shift
  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF1E40AF)],
    stops: [0.0, 0.6, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient overdueGradient = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF34D399), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient amberGradient = LinearGradient(
    colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Avatar palette — for initial-based student avatars ──────────────────
  static const List<List<Color>> avatarGradients = [
    [Color(0xFF6366F1), Color(0xFF4F46E5)], // indigo
    [Color(0xFF8B5CF6), Color(0xFF7C3AED)], // violet
    [Color(0xFF0EA5E9), Color(0xFF0284C7)], // sky
    [Color(0xFF14B8A6), Color(0xFF0D9488)], // teal
    [Color(0xFF10B981), Color(0xFF059669)], // emerald
    [Color(0xFFF59E0B), Color(0xFFD97706)], // amber
    [Color(0xFFEC4899), Color(0xFFDB2777)], // pink
    [Color(0xFFEF4444), Color(0xFFDC2626)], // red
  ];

  /// Get a deterministic gradient for a student name
  static List<Color> avatarGradientFor(String name) {
    final idx = name.isEmpty ? 0 : name.codeUnitAt(0) % avatarGradients.length;
    return avatarGradients[idx];
  }
}
