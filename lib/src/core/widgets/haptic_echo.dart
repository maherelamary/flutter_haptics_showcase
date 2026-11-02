import 'package:flutter/material.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';

/// Draws an expanding ring behind its child each time [trigger] changes —
/// the visible echo of a haptic.
///
/// ```dart
/// HapticEcho(trigger: _taps, child: button)
/// ```
///
/// Keep the echo and the haptic on the same frame; a ring that lags the
/// buzz makes both feel late.
class HapticEcho extends StatefulWidget {
  const HapticEcho({
    super.key,
    required this.trigger,
    required this.child,
    this.color = AppColors.accent,
    this.spread = 1.6,
    this.duration = const Duration(milliseconds: 520),
    this.shape = BoxShape.circle,
    this.borderRadius,
  });

  /// Change this value to fire a ring.
  final Object? trigger;
  final Widget child;
  final Color color;

  /// How far the ring grows, as a multiple of the child's size.
  final double spread;
  final Duration duration;
  final BoxShape shape;
  final BorderRadius? borderRadius;

  @override
  State<HapticEcho> createState() => _HapticEchoState();
}

class _HapticEchoState extends State<HapticEcho>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void didUpdateWidget(HapticEcho oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) _ring.forward(from: 0);
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _ring,
              builder: (context, _) {
                final t = Curves.easeOutCubic.transform(_ring.value);
                if (_ring.isDismissed || t >= 1) return const SizedBox();
                return Transform.scale(
                  scale: 1 + (widget.spread - 1) * t,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: widget.shape,
                      borderRadius: widget.shape == BoxShape.circle
                          ? null
                          : widget.borderRadius,
                      border: Border.all(
                        color: widget.color.withValues(alpha: (1 - t) * 0.8),
                        width: 2,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}
