import 'package:flutter/material.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';

/// Labelled segments showing where the user is in a multi-step flow.
///
/// Silent by itself: the flow decides whether a step change ticks (only
/// when the user moved it, never when the flow advanced on its own).
class FlowStepIndicator extends StatelessWidget {
  const FlowStepIndicator({
    super.key,
    required this.steps,
    required this.current,
    this.accent = AppColors.flows,
    this.onStepTap,
  });

  final List<String> steps;
  final int current;
  final Color accent;

  /// Tapping an earlier step goes back to it.
  final ValueChanged<int>? onStepTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onStepTap != null && i < current
                  ? () => onStepTap!(i)
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: i <= current ? accent : AppColors.surfaceHighest,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: AppTypography.eyebrow.copyWith(
                      fontSize: 9.5,
                      color: i == current
                          ? AppColors.text
                          : i < current
                          ? accent
                          : AppColors.textFaint,
                    ),
                    child: Text('${i + 1} · ${steps[i].toUpperCase()}'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
