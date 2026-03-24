import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF2E9AB2);
  static const Color secondary = Color(0xFFD95B66);
  static const Color tertiary = Color(0xFFE8A817);

  // Surfaces
  static const Color background = Color(0xFFF6F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFF0F2F7);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);

  // Semantic
  static const Color border = Color(0xFFE2E8F0);
  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);

  // Shadows
  static final List<BoxShadow> shadowSm = const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 8,
          offset: Offset(0, 1),
        ),
        BoxShadow(
          color: Color(0x06000000),
          blurRadius: 4,
          offset: Offset(0, 1),
        ),
      ];

  static final List<BoxShadow> shadowMd = const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
        BoxShadow(
          color: Color(0x05000000),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ];

  static final List<BoxShadow> shadowLg = const [
        BoxShadow(
          color: Color(0x0F000000),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
      ];
}
