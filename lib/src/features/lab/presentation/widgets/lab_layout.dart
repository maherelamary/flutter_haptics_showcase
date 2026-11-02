import 'package:flutter/material.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';

/// The frame every Lab experiment sits in: an instruction at the top, the
/// experiment filling the middle, controls within thumb reach at the bottom.
class LabLayout extends StatelessWidget {
  const LabLayout({
    super.key,
    required this.hint,
    required this.stage,
    this.status,
    this.controls,
  });

  /// One line telling the user what to do.
  final String hint;

  /// The experiment. Gets all remaining height.
  final Widget stage;

  /// Optional line under the hint: live readouts.
  final Widget? status;

  /// Optional bottom controls.
  final Widget? controls;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            hint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          if (status != null) ...[const SizedBox(height: 10), status!],
          const SizedBox(height: 12),
          Expanded(child: stage),
          if (controls != null) ...[const SizedBox(height: 16), controls!],
        ],
      ),
    );
  }
}

/// A rounded, softly lit panel for an experiment's stage.
class LabPanel extends StatelessWidget {
  const LabPanel({
    super.key,
    required this.child,
    this.glow = AppColors.lab,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final Color glow;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.outline),
        gradient: RadialGradient(
          center: const Alignment(0, -0.5),
          radius: 1.3,
          colors: [glow.withValues(alpha: 0.08), AppColors.surface],
        ),
      ),
      child: child,
    );
  }
}
