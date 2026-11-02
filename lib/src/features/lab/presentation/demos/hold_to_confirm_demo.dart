import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_patterns.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptics_providers.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/haptic_echo.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/pill_tag.dart';
import 'package:flutter_haptics_showcase/src/features/lab/domain/lab_patterns.dart';
import 'package:flutter_haptics_showcase/src/features/lab/presentation/widgets/lab_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Press and hold to commit. One rising curve plays for exactly as long as
/// the ring takes to fill; let go early and `stop()` cuts it dead.
class HoldToConfirmDemo extends ConsumerStatefulWidget {
  const HoldToConfirmDemo({super.key});

  /// How long the hold takes — matched to chargeUp's 800 ms curve.
  static const holdTime = Duration(milliseconds: 800);

  @override
  ConsumerState<HoldToConfirmDemo> createState() => _HoldToConfirmDemoState();
}

class _HoldToConfirmDemoState extends ConsumerState<HoldToConfirmDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: HoldToConfirmDemo.holdTime,
  )..addStatusListener(_onStatus);

  Timer? _fallbackTicks;
  bool _holding = false;

  /// The finger doing the holding. A second finger neither restarts the
  /// hold nor ends it.
  int? _pointer;
  bool _done = false;
  int _bursts = 0;
  int _aborts = 0;

  bool get _sustains =>
      ref.read(hapticSupportProvider).value?.supportsContinuous ?? true;

  void _onDown(PointerDownEvent event) {
    if (_done || _pointer != null) return;
    _pointer = event.pointer;
    _fallbackTicks?.cancel();
    setState(() => _holding = true);
    // From empty, not from where the deflate got to: chargeUp always starts
    // from silence, and the lock has to land on its peak.
    _ring.forward(from: 0);

    if (_sustains) {
      // One rumble, 800 ms, building to a peak: the whole hold in one call.
      FlutterHaptics.play(HapticPatterns.chargeUp);
    } else {
      // No sustained rumble here (an iPhone 7, say): climb in taps instead.
      var step = 0;
      _fallbackTicks = Timer.periodic(const Duration(milliseconds: 100), (t) {
        step++;
        FlutterHaptics.play(
          LabPatterns.tap(0.2 + 0.1 * step, 0.4 + 0.07 * step),
        );
        if (step >= 7) t.cancel();
      });
    }
  }

  void _onUp(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    if (!_holding || _done) return;
    _fallbackTicks?.cancel();
    setState(() {
      _holding = false;
      _aborts++;
    });
    // Released early: cut the rising curve, then deflate softly.
    FlutterHaptics.stop().then((_) {
      // Pressed again while stopping: the soft tap would land on the new
      // hold's rumble.
      if (!_holding && mounted) FlutterHaptics.play(HapticPatterns.soft);
    });
    _ring.animateBack(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_holding) return;
    _confirm();
  }

  void _confirm() {
    if (_done) return;
    _fallbackTicks?.cancel();
    // A screen-reader confirm mid-hold: chargeUp is still rising.
    final interrupted = _holding && _ring.value < 1;
    // Cleared first: setting the ring to 1 fires the completed status
    // synchronously, and mid-hold that would re-enter this method.
    _holding = false;
    _ring.value = 1;
    if (interrupted) {
      // Cut the rise so the lock lands on its own, not on top of it.
      FlutterHaptics.stop().then((_) => FlutterHaptics.play(AppPatterns.lock));
    } else {
      FlutterHaptics.play(AppPatterns.lock);
    }
    setState(() {
      _holding = false;
      _done = true;
      _bursts++;
    });
  }

  void _reset() {
    setState(() => _done = false);
    _ring.value = 0;
  }

  @override
  void dispose() {
    _fallbackTicks?.cancel();
    if (_holding) FlutterHaptics.stop();
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final support = ref.watch(hapticSupportProvider).value;
    final sustains = support?.supportsContinuous ?? true;
    final accent = _done ? AppColors.accent : AppColors.lab;

    return LabLayout(
      hint:
          'Press and hold until the ring closes. Let go early and the '
          'rumble stops instantly.',
      status: Row(
        children: [
          const Text('EARLY RELEASES', style: AppTypography.eyebrow),
          const SizedBox(width: 8),
          Text(
            '$_aborts',
            style: AppTypography.mono.copyWith(color: AppColors.lab),
          ),
        ],
      ),
      stage: LabPanel(
        glow: accent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HapticEcho(
              trigger: _bursts,
              color: AppColors.accent,
              spread: 1.8,
              // A screen reader's double-tap is a press and an immediate
              // release, which aborts the hold, so it gets an action.
              child: Semantics(
                button: true,
                label: 'Hold to delete archive',
                onTap: _done ? null : _confirm,
                child: Listener(
                  onPointerDown: _onDown,
                  onPointerUp: _onUp,
                  onPointerCancel: _onUp,
                  child: AnimatedScale(
                    scale: _holding ? 0.95 : 1,
                    duration: const Duration(milliseconds: 160),
                    child: AnimatedBuilder(
                      animation: _ring,
                      builder: (context, _) => CustomPaint(
                        painter: _RingPainter(
                          progress: _ring.value,
                          color: accent,
                          done: _done,
                        ),
                        child: SizedBox(
                          width: 208,
                          height: 208,
                          child: Center(
                            child: Icon(
                              _done
                                  ? Icons.check_rounded
                                  : Icons.delete_forever_rounded,
                              size: 56,
                              color: _done ? AppColors.onAccent : accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              _done ? 'Archive deleted' : 'Hold to delete archive',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              _done
                  ? '2,418 messages are gone.'
                  : 'Irreversible actions earn a deliberate gesture.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
      controls: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              children: [
                PillTag(
                  sustains ? 'continuous' : 'taps only',
                  color: sustains ? AppColors.accent : AppColors.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    sustains
                        ? 'This device sustains a rumble, so chargeUp plays as '
                              'one rising curve.'
                        : 'No sustained rumble here — the hold climbs in seven '
                              'taps instead.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          AnimatedOpacity(
            opacity: _done ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: TextButton.icon(
              onPressed: _done ? _reset : null,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reset'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.done,
  });

  final double progress;
  final Color color;
  final bool done;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    // Glow grows with the hold.
    canvas.drawCircle(
      center,
      radius * 0.78,
      Paint()
        ..color = color.withValues(alpha: done ? 1 : 0.08 + 0.25 * progress)
        ..maskFilter = done
            ? null
            : MaskFilter.blur(BlurStyle.normal, 6 + 24 * progress),
    );
    canvas.drawCircle(
      center,
      radius * 0.72,
      Paint()..color = done ? color : AppColors.surfaceRaised,
    );

    final track = Paint()
      ..color = AppColors.surfaceHighest
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(center, radius - 8, track);

    if (progress <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: radius - 8);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: [color.withValues(alpha: 0.35), color],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 10,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.done != done;
}
