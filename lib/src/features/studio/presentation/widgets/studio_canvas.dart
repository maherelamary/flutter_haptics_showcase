import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/pattern_waveform.dart';
import 'package:flutter_haptics_showcase/src/features/studio/domain/studio_draft.dart';

/// The Studio's big waveform: the pattern as it will be felt, the selected
/// event highlighted behind it, and a playhead while it plays.
///
/// Tap anywhere on it to select the event at that moment.
class StudioCanvas extends StatelessWidget {
  const StudioCanvas({
    super.key,
    required this.pattern,
    required this.spans,
    required this.selectedId,
    required this.onSelect,
    this.elapsedMs,
    this.height = 132,
  });

  /// Shortest timeline drawn, so one tap does not fill the canvas.
  static const minDuration = Duration(milliseconds: 400);

  /// The pattern as displayed — already degraded for the preview tier.
  final HapticPattern pattern;
  final List<StudioSpan> spans;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  /// Playback position, or null when stopped.
  final double? elapsedMs;
  final double height;

  /// The span the painter maps across the full width — the same rule the
  /// waveform itself uses.
  int get totalMs => math.max(
        pattern.duration.inMilliseconds,
        minDuration.inMilliseconds,
      );

  void _select(double dx, double width) {
    if (spans.isEmpty || width <= 0) return;
    final t = dx / width * totalMs;
    const slop = 14;
    StudioSpan? hit;
    for (final span in spans) {
      if (t >= span.startMs - slop && t <= span.endMs + slop) {
        hit = span;
        break;
      }
    }
    hit ??= spans.reduce(
      (a, b) => (a.centerMs - t).abs() <= (b.centerMs - t).abs() ? a : b,
    );
    onSelect(hit.id);
  }

  @override
  Widget build(BuildContext context) {
    final total = totalMs;
    final elapsed = elapsedMs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) =>
                _select(details.localPosition.dx, constraints.maxWidth),
            child: SizedBox(
              height: height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _SpanPainter(
                      spans: spans,
                      selectedId: selectedId,
                      totalMs: total,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: PatternWaveform(
                      pattern: pattern,
                      color: AppColors.studio,
                      height: height - 8,
                      minDuration: minDuration,
                      progress: elapsed == null ? null : elapsed / total,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('0', style: AppTypography.eyebrow),
            const Spacer(),
            Text('${total ~/ 2} ms', style: AppTypography.eyebrow),
            const Spacer(),
            Text('$total ms', style: AppTypography.eyebrow),
          ],
        ),
      ],
    );
  }
}

/// Event boundaries along the floor, and a band behind the selected event.
class _SpanPainter extends CustomPainter {
  _SpanPainter({
    required this.spans,
    required this.selectedId,
    required this.totalMs,
  });

  final List<StudioSpan> spans;
  final int? selectedId;
  final int totalMs;

  @override
  void paint(Canvas canvas, Size size) {
    if (totalMs <= 0) return;
    final pxPerMs = size.width / totalMs;

    for (final span in spans) {
      final x0 = span.startMs * pxPerMs;
      final x1 = span.endMs * pxPerMs;
      if (span.id == selectedId) {
        final width = math.max(10.0, x1 - x0);
        final left = math.max(0.0, (x0 + x1) / 2 - width / 2);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, 0, width, size.height),
            const Radius.circular(6),
          ),
          Paint()..color = AppColors.studio.withValues(alpha: 0.14),
        );
      }
      canvas.drawLine(
        Offset(x0, size.height - 6),
        Offset(x0, size.height),
        Paint()
          ..color = span.id == selectedId
              ? AppColors.studio
              : AppColors.outlineStrong
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_SpanPainter oldDelegate) =>
      oldDelegate.spans != spans ||
      oldDelegate.selectedId != selectedId ||
      oldDelegate.totalMs != totalMs;
}
