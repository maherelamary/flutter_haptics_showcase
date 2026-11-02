import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_patterns.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptic_pacer.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/haptic_echo.dart';
import 'package:flutter_haptics_showcase/src/features/lab/domain/lab_patterns.dart';
import 'package:flutter_haptics_showcase/src/features/lab/presentation/widgets/lab_layout.dart';

/// Slide a knob to commit. Ticks tighten and strengthen as it travels, so the
/// approach to the point of no return can be felt.
class SlideToConfirmDemo extends StatefulWidget {
  const SlideToConfirmDemo({super.key});

  /// How many ticks a full slide plays. They bunch up towards the end.
  static const ticks = 16;

  @override
  State<SlideToConfirmDemo> createState() => _SlideToConfirmDemoState();
}

class _SlideToConfirmDemoState extends State<SlideToConfirmDemo>
    with SingleTickerProviderStateMixin {
  static const _knob = 64.0;
  static const _trackHeight = 72.0;

  // Five prepared strengths, from a whisper to a firm click.
  final List<HapticHandle> _ladder = [
    for (final p in LabPatterns.ladder(
      count: 5,
      from: 0.25,
      to: 0.9,
      sharpness: 0.4,
      sharpnessTo: 0.95,
    ))
      FlutterHaptics.register(p),
  ];

  // Shared across the handles above. Each handle paces only itself, so
  // without this, switching between them could still fire faster than
  // the actuator can separate.
  final _pacer = HapticPacer(minInterval: const Duration(milliseconds: 28));

  late final AnimationController _spring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..addListener(_onSpring);

  double _progress = 0;
  double _springFrom = 0;
  int _lastTick = 0;
  int _ticksFelt = 0;
  bool _confirmed = false;
  int _confirmations = 0;

  /// Tick index for a progress: `n · p^1.8` makes the spacing shrink as the
  /// knob nears the end, so density rises with tension.
  static int _tickAt(double p) =>
      (SlideToConfirmDemo.ticks * math.pow(p.clamp(0.0, 1.0), 1.8)).floor();

  void _onSpring() {
    final t = Curves.easeOutBack.transform(_spring.value);
    setState(() => _progress = (_springFrom * (1 - t)).clamp(0.0, 1.0));
  }

  void _onDragStart(DragStartDetails _) {
    if (_confirmed) return;
    _spring.stop();
    _lastTick = _tickAt(_progress);
    _pacer.reset();
  }

  void _onDragUpdate(DragUpdateDetails details, double travel) {
    if (_confirmed) return;
    final next = (_progress + details.delta.dx / travel).clamp(0.0, 1.0);
    final tick = _tickAt(next);
    if (tick > _lastTick && _pacer.ready()) {
      final rung = (next * _ladder.length).floor().clamp(0, _ladder.length - 1);
      // Counted only where the handle played: its own pacing floor can be
      // above this demo's on a weaker actuator.
      _ladder[rung].play().then((route) {
        if (route != HapticRoute.none && mounted) setState(() => _ticksFelt++);
      });
    }
    _lastTick = tick;
    setState(() => _progress = next);
    if (next >= 0.985) _confirm();
  }

  void _onDragEnd(DragEndDetails _) {
    if (_confirmed || _progress == 0) return;
    // Let go early: spring home with a soft, deflating tap.
    FlutterHaptics.play(HapticPatterns.soft);
    _springFrom = _progress;
    _spring.forward(from: 0);
  }

  void _confirm() {
    // A screen-reader confirm can land mid spring-back, which would drag the
    // knob home while the state says sent.
    _spring.stop();
    // One strong moment. The ticks were the build-up; this is the payoff.
    FlutterHaptics.play(AppPatterns.lock);
    setState(() {
      _confirmed = true;
      _progress = 1;
      _confirmations++;
    });
  }

  void _reset() {
    setState(() {
      _confirmed = false;
      _progress = 0;
      _ticksFelt = 0;
      _lastTick = 0;
    });
  }

  @override
  void dispose() {
    _spring.dispose();
    for (final h in _ladder) {
      h.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _confirmed ? AppColors.accent : AppColors.lab;

    return LabLayout(
      hint:
          'Drag the knob all the way. The ticks get closer and stronger '
          'as you approach the end; let go early and it springs back.',
      status: Row(
        children: [
          const Text('TICKS FELT', style: AppTypography.eyebrow),
          const SizedBox(width: 8),
          Text(
            '$_ticksFelt',
            style: AppTypography.mono.copyWith(color: AppColors.lab),
          ),
          const Spacer(),
          Text(
            '${(_progress * 100).round()}%',
            style: AppTypography.mono.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
      stage: LabPanel(
        glow: accent,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HapticEcho(
                  trigger: _confirmations,
                  color: AppColors.accent,
                  spread: 2.2,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: _confirmed ? 1 : 0.1),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(
                            alpha: 0.15 + 0.45 * _progress,
                          ),
                          blurRadius: 20 + 40 * _progress,
                        ),
                      ],
                    ),
                    child: Icon(
                      _confirmed ? Icons.check_rounded : Icons.send_rounded,
                      size: 40,
                      color: _confirmed ? AppColors.onAccent : accent,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _confirmed ? 'Sent' : r'Send $240.00',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  _confirmed ? 'Lina has it.' : 'to Lina Haddad',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 28),
                _TensionBars(progress: _progress, color: accent),
              ],
            ),
          ),
        ),
      ),
      controls: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final travel = constraints.maxWidth - _knob - 8;
              // A screen reader cannot drag the knob, so it gets an action.
              // One label, matching the visible text so voice control can
              // name it; the track's own text would otherwise be read too.
              return Semantics(
                button: true,
                label: _confirmed ? 'Sent' : 'Slide to send',
                onTap: _confirmed ? null : _confirm,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: _onDragStart,
                  onHorizontalDragUpdate: (d) => _onDragUpdate(d, travel),
                  onHorizontalDragEnd: _onDragEnd,
                  child: _Track(
                    progress: _progress,
                    travel: travel,
                    knob: _knob,
                    height: _trackHeight,
                    confirmed: _confirmed,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          AnimatedOpacity(
            opacity: _confirmed ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: TextButton.icon(
              onPressed: _confirmed ? _reset : null,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reset'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Track extends StatelessWidget {
  const _Track({
    required this.progress,
    required this.travel,
    required this.knob,
    required this.height,
    required this.confirmed,
  });

  final double progress;
  final double travel;
  final double knob;
  final double height;
  final bool confirmed;

  @override
  Widget build(BuildContext context) {
    final accent = confirmed ? AppColors.accent : AppColors.lab;
    final x = 4 + travel * progress;
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(height / 2),
                border: Border.all(color: AppColors.outline),
              ),
            ),
          ),
          // The fill that follows the knob.
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: x + knob + 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height / 2),
                gradient: LinearGradient(
                  colors: [
                    accent.withValues(alpha: 0.05),
                    accent.withValues(alpha: 0.2 + 0.5 * progress),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Opacity(
                opacity: (1 - progress * 1.6).clamp(0.0, 1.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Slide to send',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.keyboard_double_arrow_right_rounded,
                      color: AppColors.textFaint,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: x,
            top: (height - knob) / 2,
            child: Container(
              width: knob,
              height: knob,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.3 + 0.4 * progress),
                    blurRadius: 12 + 24 * progress,
                  ),
                ],
              ),
              child: Icon(
                confirmed ? Icons.lock_rounded : Icons.arrow_forward_rounded,
                color: AppColors.onAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A row of bars, one per tick, lit as the knob passes each — the tick
/// schedule made visible: notice how they crowd towards the end.
class _TensionBars extends StatelessWidget {
  const _TensionBars({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const n = SlideToConfirmDemo.ticks;
    return SizedBox(
      height: 44,
      child: CustomPaint(
        size: const Size(double.infinity, 44),
        painter: _TensionPainter(progress: progress, color: color, ticks: n),
      ),
    );
  }
}

class _TensionPainter extends CustomPainter {
  _TensionPainter({
    required this.progress,
    required this.color,
    required this.ticks,
  });

  final double progress;
  final Color color;
  final int ticks;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 1; i <= ticks; i++) {
      // Inverse of the tick schedule: where tick i lands along the track.
      final at = math.pow(i / ticks, 1 / 1.8).toDouble();
      final x = at * (size.width - 4) + 2;
      final strength = 0.25 + 0.65 * at;
      final h = size.height * strength;
      final lit = progress >= at;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 1.5, size.height - h, 3, h),
          const Radius.circular(1.5),
        ),
        Paint()
          ..color = lit
              ? color.withValues(alpha: 0.5 + 0.5 * strength)
              : AppColors.surfaceHighest,
      );
    }
  }

  @override
  bool shouldRepaint(_TensionPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
