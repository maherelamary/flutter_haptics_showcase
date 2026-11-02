import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/pattern_math.dart';

/// Draws a pattern as a waveform: time runs left to right, height is
/// intensity, brightness is sharpness.
///
/// Taps are bars; rumbles are filled areas that follow their intensity curve.
class PatternWaveform extends StatelessWidget {
  const PatternWaveform({
    super.key,
    required this.pattern,
    this.color = AppColors.accent,
    this.height = 48,
    this.minDuration = const Duration(milliseconds: 240),
    this.progress,
    this.showBaseline = true,
  });

  final HapticPattern pattern;
  final Color color;
  final double height;

  /// Short patterns are drawn on at least this much time, so a single tap
  /// does not fill the whole width.
  final Duration minDuration;

  /// A playhead position, 0.0–1.0, or null for none.
  final double? progress;

  final bool showBaseline;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: WaveformPainter(
          pattern: pattern,
          color: color,
          minDuration: minDuration,
          progress: progress,
          showBaseline: showBaseline,
        ),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  WaveformPainter({
    required this.pattern,
    required this.color,
    required this.minDuration,
    this.progress,
    this.showBaseline = true,
  });

  final HapticPattern pattern;
  final Color color;
  final Duration minDuration;
  final double? progress;
  final bool showBaseline;

  @override
  void paint(Canvas canvas, Size size) {
    final totalMs = math.max(
      pattern.duration.inMilliseconds,
      minDuration.inMilliseconds,
    );
    if (totalMs <= 0 || size.width <= 0) return;

    final pxPerMs = size.width / totalMs;
    final baseline = size.height - 1;
    final usable = size.height - 2;

    if (showBaseline) {
      canvas.drawLine(
        Offset(0, baseline),
        Offset(size.width, baseline),
        Paint()
          ..color = AppColors.outlineStrong
          ..strokeWidth = 1,
      );
    }

    for (final event in pattern.events) {
      switch (event) {
        case ContinuousEvent():
          _paintContinuous(canvas, event, pxPerMs, baseline, usable);
        case TransientEvent():
          break;
      }
    }
    // Taps on top, so a tap over a rumble stays visible.
    for (final event in pattern.events) {
      switch (event) {
        case TransientEvent():
          _paintTransient(canvas, event, pxPerMs, baseline, usable);
        case ContinuousEvent():
          break;
      }
    }

    final p = progress;
    if (p != null) {
      final x = (p.clamp(0.0, 1.0)) * size.width;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = AppColors.text.withValues(alpha: 0.8)
          ..strokeWidth = 1.5,
      );
    }
  }

  void _paintTransient(
    Canvas canvas,
    TransientEvent event,
    double pxPerMs,
    double baseline,
    double usable,
  ) {
    final x = event.delay.inMilliseconds * pxPerMs;
    final width = math.max(3.0, HapticEvent.transientWidth.inMilliseconds * pxPerMs * 0.45);
    final h = math.max(2.0, event.intensity.clamp(0.0, 1.0) * usable);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.45 + 0.55 * event.sharpness.clamp(0.0, 1.0));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, baseline - h, width, h),
        Radius.circular(width / 2),
      ),
      paint,
    );
  }

  void _paintContinuous(
    Canvas canvas,
    ContinuousEvent event,
    double pxPerMs,
    double baseline,
    double usable,
  ) {
    final x0 = event.delay.inMilliseconds * pxPerMs;
    final w = event.duration.inMilliseconds * pxPerMs;
    if (w <= 0) return;
    final samples = math.max(6, (w / 3).round());
    final top = Path()..moveTo(x0, baseline);
    for (var i = 0; i <= samples; i++) {
      final t = i / samples;
      final v = PatternMath.valueAt(event.intensity, t).clamp(0.0, 1.0);
      top.lineTo(x0 + w * t, baseline - v * usable);
    }
    final area = Path.from(top)
      ..lineTo(x0 + w, baseline)
      ..close();

    final sharp = PatternMath.meanOf(event.sharpness).clamp(0.0, 1.0);
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.25 + 0.35 * sharp),
            color.withValues(alpha: 0.04),
          ],
        ).createShader(Rect.fromLTWH(x0, baseline - usable, w, usable)),
    );
    canvas.drawPath(
      top,
      Paint()
        ..color = color.withValues(alpha: 0.6 + 0.4 * sharp)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) =>
      oldDelegate.pattern != pattern ||
      oldDelegate.color != color ||
      oldDelegate.progress != progress ||
      oldDelegate.minDuration != minDuration;
}
