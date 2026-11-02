import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_patterns.dart';

/// A slider you could set with your eyes closed: notches you feel, a
/// magnetic centre, and end stops that say "no further".
class DetentSliderDemo extends StatefulWidget {
  const DetentSliderDemo({super.key});

  @override
  State<DetentSliderDemo> createState() => _DetentSliderDemoState();
}

class _DetentSliderDemoState extends State<DetentSliderDemo>
    with SingleTickerProviderStateMixin {
  static const _height = 72.0;
  static const _magnetRadius = 3.0;

  /// The centre detent: heavier than a notch, so it reads as "home".
  static const _magnetPattern = HapticPattern([
    TransientEvent(intensity: 0.95, sharpness: 0.6),
  ]);

  // Handles pace themselves: a fast drag across several notches plays as
  // many distinct detents as the actuator can separate, and no more.
  final HapticHandle _detent = FlutterHaptics.register(AppPatterns.detent);
  final HapticHandle _magnet = FlutterHaptics.register(_magnetPattern);
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  double _value = 30;
  bool _atLimit = false;
  int? _pulseNotch;
  String _last = 'drag the thumb';

  void _update(double dx, double width) {
    if (width <= 0) return;
    var next = (dx / width * 100).clamp(0.0, 100.0);
    final magnetic = (next - 50).abs() <= _magnetRadius;
    if (magnetic) next = 50;

    if (magnetic && _value != 50) {
      _magnet.play();
      _flash(5, 'magnet → 50');
    } else if (!magnetic) {
      final notch = _crossedNotch(_value, next);
      if (notch != null) {
        _detent.play();
        _flash(notch, 'detent → ${notch * 10}');
      }
    }

    // An end stop speaks once per arrival, not on every frame spent pinned.
    final atLimit = next <= 0 || next >= 100;
    if (atLimit && !_atLimit) {
      FlutterHaptics.perform(AppHaptics.limit);
      _flash(next <= 0 ? 0 : 10, 'limit → ${next.round()}');
    }
    _atLimit = atLimit;

    setState(() => _value = next);
  }

  /// The notch (1–9) between [from] and [to], if one was crossed.
  int? _crossedNotch(double from, double to) {
    for (var k = 1; k <= 9; k++) {
      final n = k * 10.0;
      if ((from < n && to >= n) || (from > n && to <= n)) return k;
    }
    return null;
  }

  void _flash(int notch, String label) {
    _pulseNotch = notch;
    _last = label;
    _pulse.forward(from: 0);
  }

  @override
  void dispose() {
    _detent.dispose();
    _magnet.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _value.round().toString().padLeft(3),
              style: AppTypography.mono.copyWith(
                fontSize: 36,
                height: 1,
                fontWeight: FontWeight.w700,
                color: _value == 50 ? AppColors.accent : AppColors.text,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '%',
                style: AppTypography.mono.copyWith(color: AppColors.textMuted),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                _last,
                style: AppTypography.mono.copyWith(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _update(d.localPosition.dx, width),
              onHorizontalDragStart: (d) => _update(d.localPosition.dx, width),
              onHorizontalDragUpdate: (d) =>
                  _update(d.localPosition.dx, width),
              child: SizedBox(
                height: _height,
                width: width,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => CustomPaint(
                    painter: _DetentPainter(
                      value: _value,
                      pulseNotch: _pulseNotch,
                      pulse: _pulse.isAnimating ? _pulse.value : null,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        // Thirds, so a narrow phone truncates a label instead of overflowing.
        const Row(
          children: [
            Expanded(child: _Mark('0 · limit', TextAlign.start)),
            Expanded(child: _Mark('50 · magnet', TextAlign.center)),
            Expanded(child: _Mark('limit · 100', TextAlign.end)),
          ],
        ),
      ],
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark(this.label, this.align);

  final String label;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => Text(
        label,
        textAlign: align,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.eyebrow,
      );
}

class _DetentPainter extends CustomPainter {
  _DetentPainter({required this.value, this.pulseNotch, this.pulse});

  final double value;
  final int? pulseNotch;
  final double? pulse;

  static const _inset = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    const left = _inset;
    final right = size.width - _inset;
    final span = right - left;
    double xFor(double v) => left + span * v / 100;

    // Track.
    final track = Paint()
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(left, cy),
      Offset(right, cy),
      track..color = AppColors.surfaceHighest,
    );
    canvas.drawLine(
      Offset(left, cy),
      Offset(xFor(value), cy),
      track..color = AppColors.accent,
    );

    // Notches, lit once passed.
    for (var k = 0; k <= 10; k++) {
      final v = k * 10.0;
      final x = xFor(v);
      final major = k == 0 || k == 5 || k == 10;
      final h = major ? 22.0 : 12.0;
      canvas.drawLine(
        Offset(x, cy + 10),
        Offset(x, cy + 10 + h * 0.6),
        Paint()
          ..strokeWidth = major ? 2 : 1.4
          ..strokeCap = StrokeCap.round
          ..color = value >= v ? AppColors.accent : AppColors.outlineStrong,
      );
    }

    // Pulse ring at the notch just felt.
    final p = pulse;
    final n = pulseNotch;
    if (p != null && n != null) {
      canvas.drawCircle(
        Offset(xFor(n * 10.0), cy),
        10 + 18 * p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.accent.withValues(alpha: (1 - p) * 0.8),
      );
    }

    // Thumb.
    final tx = xFor(value);
    canvas.drawCircle(
      Offset(tx, cy),
      16,
      Paint()
        ..color = AppColors.accent.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(Offset(tx, cy), 12, Paint()..color = AppColors.accent);
    canvas.drawCircle(Offset(tx, cy), 4, Paint()..color = AppColors.onAccent);
  }

  @override
  bool shouldRepaint(_DetentPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.pulse != pulse ||
      oldDelegate.pulseNotch != pulseNotch;
}
