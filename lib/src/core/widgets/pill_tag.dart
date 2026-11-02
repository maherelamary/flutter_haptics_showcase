import 'package:flutter/material.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';

/// A small mono label: `SYSTEM`, `API 34`, `AppHaptics.tap`.
class PillTag extends StatelessWidget {
  const PillTag(
    this.label, {
    super.key,
    this.color = AppColors.textMuted,
    this.icon,
    this.filled = false,
    this.uppercase = true,
  });

  final String label;
  final Color color;
  final IconData? icon;

  /// Solid background with dark text, for emphasis.
  final bool filled;

  /// Off for anything whose case carries meaning: a Dart name like
  /// `AppHaptics.tap`, or `iOS`.
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? AppColors.onAccent : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: filled ? 1 : 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            uppercase ? label.toUpperCase() : label,
            style: AppTypography.eyebrow.copyWith(
              color: foreground,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }
}
