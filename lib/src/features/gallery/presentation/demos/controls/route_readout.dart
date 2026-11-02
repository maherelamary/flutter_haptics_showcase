import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/safe_animated_switcher.dart';

/// A one-line readout under a control: what was called, and what it did.
///
/// `perform(press) → system`, `play(pop) → pattern`, or a silent note.
class RouteReadout extends StatelessWidget {
  const RouteReadout({
    super.key,
    required this.call,
    this.route,
    this.silent = false,
  });

  /// Shown before any route arrives, or as the whole note when [silent].
  final String call;

  /// What the call returned, once it has.
  final HapticRoute? route;

  /// Marks a deliberately silent interaction.
  final bool silent;

  static Color colorFor(HapticRoute? route) => switch (route) {
        HapticRoute.system => AppColors.system,
        HapticRoute.pattern => AppColors.pattern,
        HapticRoute.none => AppColors.silent,
        null => AppColors.textFaint,
      };

  @override
  Widget build(BuildContext context) {
    final color = silent ? AppColors.silent : colorFor(route);
    final text = silent || route == null ? call : '$call → ${route!.name}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: SafeAnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              text,
              key: ValueKey(text),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.mono.copyWith(
                fontSize: 10.5,
                height: 1.3,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
