import 'package:flutter/material.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';

/// Type scale: tight, confident headings over quiet body text, with a mono
/// face for anything that is code or a haptic's name.
abstract final class AppTypography {
  static const _mono = 'Menlo';
  static const _monoFallback = ['RobotoMono', 'monospace', 'Courier'];

  /// Code, constants and pattern names.
  static const mono = TextStyle(
    fontFamily: _mono,
    fontFamilyFallback: _monoFallback,
    fontSize: 12.5,
    height: 1.55,
    color: AppColors.text,
  );

  /// Small uppercase mono labels: route tags, section eyebrows.
  static const eyebrow = TextStyle(
    fontFamily: _mono,
    fontFamilyFallback: _monoFallback,
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    color: AppColors.textMuted,
  );

  static TextTheme get textTheme {
    final base = Typography.material2021(platform: TargetPlatform.iOS).white;
    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.6,
        height: 1.05,
        color: AppColors.text,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: AppColors.text,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: AppColors.text,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: AppColors.text,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: AppColors.text,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.45,
        color: AppColors.text,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.45,
        color: AppColors.textMuted,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12.5,
        height: 1.4,
        color: AppColors.textMuted,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: AppColors.textMuted,
      ),
    );
  }
}
