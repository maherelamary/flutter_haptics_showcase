import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/safe_animated_switcher.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/shaker.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/controls/route_readout.dart';

/// A 0–10 quantity stepper: ticks per step, a bump at the limits, and a
/// long-press auto-repeat that speeds up.
class QuantityStepperDemo extends StatefulWidget {
  const QuantityStepperDemo({super.key});

  @override
  State<QuantityStepperDemo> createState() => _QuantityStepperDemoState();
}

class _QuantityStepperDemoState extends State<QuantityStepperDemo> {
  static const _min = 0;
  static const _max = 10;
  static const _price = 4.5;

  final ShakeController _shake = ShakeController();
  // Auto-repeat speeds up to a step every 60 ms; the handle's own floor
  // keeps each tick distinct on hardware that needs a longer gap.
  final HapticHandle _repeatTick =
      FlutterHaptics.register(HapticPatterns.selection);

  Timer? _repeat;
  int _qty = 2;
  int _direction = 1;
  String _call = 'tap or hold − / +';
  HapticRoute? _route;

  /// One step. Returns false when it ran into a limit.
  bool _step(int delta, {bool repeating = false}) {
    final next = _qty + delta;
    if (next < _min || next > _max) {
      _hitLimit();
      return false;
    }
    if (repeating) {
      _repeatTick.play();
      setState(() {
        _qty = next;
        _direction = delta;
        _call = 'handle(selection) · repeating';
        _route = null;
      });
    } else {
      setState(() {
        _qty = next;
        _direction = delta;
        _call = 'perform(tick)';
        _route = null;
      });
      FlutterHaptics.perform(AppHaptics.tick).then((route) {
        if (mounted) setState(() => _route = route);
      });
    }
    return true;
  }

  void _hitLimit() {
    _stopRepeat();
    _shake.shake();
    setState(() {
      _call = 'perform(limit)';
      _route = null;
    });
    FlutterHaptics.perform(AppHaptics.limit).then((route) {
      if (mounted) setState(() => _route = route);
    });
  }

  void _startRepeat(int delta) {
    // Holding − and + together must not leave an orphaned repeat running.
    _stopRepeat();
    var interval = 220.0;
    void schedule() {
      _repeat = Timer(Duration(milliseconds: interval.round()), () {
        if (!mounted) return;
        if (!_step(delta, repeating: true)) return;
        // Each step comes a little sooner, down to a floor.
        interval = math.max(60, interval * 0.82);
        schedule();
      });
    }

    if (_step(delta, repeating: true)) schedule();
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  void dispose() {
    _stopRepeat();
    _repeatTick.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surfaceHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.local_cafe_rounded,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cold brew', style: theme.textTheme.titleSmall),
                  Text('4.50 each · max 10', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Shaker(
          controller: _shake,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StepButton(
                icon: Icons.remove_rounded,
                enabled: _qty > _min,
                onTap: () => _step(-1),
                onHoldStart: () => _startRepeat(-1),
                onHoldEnd: _stopRepeat,
              ),
              SizedBox(
                width: 96,
                child: Center(
                  child: SafeAnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    transitionBuilder: (child, animation) => SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(0, _direction > 0 ? 0.5 : -0.5),
                        end: Offset.zero,
                      ).animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Text(
                      '$_qty',
                      key: ValueKey(_qty),
                      style: AppTypography.mono.copyWith(
                        fontSize: 40,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: _qty == _max || _qty == _min
                            ? AppColors.warning
                            : AppColors.text,
                      ),
                    ),
                  ),
                ),
              ),
              _StepButton(
                icon: Icons.add_rounded,
                enabled: _qty < _max,
                onTap: () => _step(1),
                onHoldStart: () => _startRepeat(1),
                onHoldEnd: _stopRepeat,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Total ${(_qty * _price).toStringAsFixed(2)}',
            style: AppTypography.mono.copyWith(color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: RouteReadout(call: _call, route: _route),
        ),
      ],
    );
  }
}

/// A round − / + button that taps, and repeats while held.
///
/// It stays tappable at the limit on purpose: the bump and shake explain
/// why nothing changed, which a greyed-out, silent button cannot.
class _StepButton extends StatefulWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  @override
  State<_StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<_StepButton> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      onLongPressStart: (_) {
        _set(true);
        widget.onHoldStart();
      },
      onLongPressEnd: (_) {
        _set(false);
        widget.onHoldEnd();
      },
      onLongPressCancel: () {
        _set(false);
        widget.onHoldEnd();
      },
      child: AnimatedScale(
        scale: _down ? 0.9 : 1,
        duration: const Duration(milliseconds: 110),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.enabled
                ? AppColors.surfaceHighest
                : AppColors.surfaceRaised,
            border: Border.all(
              color: _down ? AppColors.accent : AppColors.outlineStrong,
            ),
          ),
          child: Icon(
            widget.icon,
            color: widget.enabled ? AppColors.text : AppColors.textFaint,
          ),
        ),
      ),
    );
  }
}
