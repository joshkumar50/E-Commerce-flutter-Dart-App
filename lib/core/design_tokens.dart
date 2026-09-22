import 'package:flutter/material.dart';

/// Centralized Design Tokens for the Grocery Commerce Platform.
/// Defines unified color palette, spacing, radii, elevations, motion, and formatting.

class AppColors {
  // Brand / Primary Emerald Palette
  static const Color primary = Color(0xFF059669); // Emerald 600
  static const Color primaryDark = Color(0xFF047857); // Emerald 700
  static const Color primaryLight = Color(0xFFD1FAE5); // Emerald 100
  static const Color primarySoft = Color(0xFFECFDF5); // Emerald 50

  // Secondary & Accents
  static const Color accent = Color(0xFFF59E0B); // Amber 500
  static const Color accentLight = Color(0xFFFEF3C7); // Amber 100
  static const Color accentSoft = Color(0xFFFFFBEB); // Amber 50

  // Alert & Sale Badges
  static const Color saleRed = Color(0xFFEF4444); // Coral Red 500
  static const Color saleRedLight = Color(0xFFFEE2E2); // Red 100
  static const Color saleRedSoft = Color(0xFFFEF2F2); // Red 50

  // Backgrounds & Neutral Surfaces
  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFF1F5F9); // Slate 100
  static const Color surfaceSubtle = Color(0xFFF8FAFC); // Slate 50

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0); // Slate 200
  static const Color borderLight = Color(0xFFF1F5F9); // Slate 100
  static const Color borderDark = Color(0xFFCBD5E1); // Slate 300

  // Typography Tokens
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400

  // Status Colors
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color info = Color(0xFF3B82F6); // Blue 500
  static const Color infoLight = Color(0xFFEFF6FF);

  // Category Pastel Accent Backgrounds
  static const Color pastelGreen = Color(0xFFE8F5E9);
  static const Color pastelOrange = Color(0xFFFFF3E0);
  static const Color pastelBlue = Color(0xFFE3F2FD);
  static const Color pastelPurple = Color(0xFFF3E5F5);
  static const Color pastelPink = Color(0xFFFCE4EC);
  static const Color pastelYellow = Color(0xFFFFFDE7);
}

class AppSpacing {
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double huge = 32.0;
  static const double giant = 40.0;
}

class AppRadius {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double full = 999.0;

  static final BorderRadius r8 = BorderRadius.circular(sm);
  static final BorderRadius r12 = BorderRadius.circular(md);
  static final BorderRadius r16 = BorderRadius.circular(lg);
  static final BorderRadius r20 = BorderRadius.circular(xl);
  static final BorderRadius rPill = BorderRadius.circular(full);
}

class AppShadows {
  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> floating = [
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 20,
      offset: Offset(0, 6),
    ),
  ];
}

class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);

  static const Curve standard = Curves.easeInOutCubic;
  static const Curve emphasized = Curves.easeOutBack;
  static const Curve decelerate = Curves.easeOutCubic;
  static const Curve spring = Curves.elasticOut;
}

class AppCurrency {
  static const String symbol = '₹';

  static String format(num amount, {bool showDecimals = true}) {
    if (!showDecimals || amount.truncateToDouble() == amount) {
      return '$symbol${amount.toInt()}';
    }
    return '$symbol${amount.toStringAsFixed(2)}';
  }
}
