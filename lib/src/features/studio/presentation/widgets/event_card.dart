import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/pattern_math.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/pattern_waveform.dart';
import 'package:flutter_haptics_showcase/src/features/studio/domain/studio_draft.dart';
import 'package:flutter_haptics_showcase/src/features/studio/domain/studio_event.dart';

/// One event on the Studio timeline. Collapsed it is a summary; selected it
/// opens its controls.
///
/// Sliders update the draft live but stay silent while dragging — a buzz
/// per slider tick would drown the thing being designed. Releasing a slider
/// auditions the event once.
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.index,
    required this.selected,
    required this.onTap,
    required this.onChanged,
    required this.onAudition,
    required this.onDuplicate,
    required this.onDelete,
  });

  final StudioEvent event;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  /// Live edits, while a control moves.
  final ValueChanged<StudioEvent> onChanged;

  /// A finished edit: play this event once.
  final ValueChanged<StudioEvent> onAudition;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  void _commit(StudioEvent next) {
    onChanged(next);
    onAudition(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final single = StudioDraft.single(event);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF17141E) : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? AppColors.studio.withValues(alpha: 0.7)
              : AppColors.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        size: 20,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ),
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.studio.withValues(
                        alpha: selected ? 0.22 : 0.1,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      event.isTap
                          ? Icons.fiber_manual_record_rounded
                          : Icons.waves_rounded,
                      size: event.isTap ? 12 : 17,
                      color: AppColors.studio,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${index + 1}  ${event.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _summary(event, index),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.mono.copyWith(
                            fontSize: 10.5,
                            height: 1.3,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 52,
                    child: PatternWaveform(
                      pattern: single,
                      color: AppColors.studio,
                      height: 22,
                      showBaseline: false,
                      minDuration: Duration(
                        milliseconds: event.isTap ? 120 : math.max(1, event.durationMs),
                      ),
                    ),
                  ),
                  PopupMenuButton<_EventAction>(
                    tooltip: 'More',
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                    color: AppColors.surfaceRaised,
                    onSelected: (action) {
                      switch (action) {
                        case _EventAction.duplicate:
                          onDuplicate();
                        case _EventAction.delete:
                          onDelete();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _EventAction.duplicate,
                        child: _MenuRow(Icons.copy_all_rounded, 'Duplicate'),
                      ),
                      PopupMenuItem(
                        value: _EventAction.delete,
                        child: _MenuRow(
                          Icons.delete_outline_rounded,
                          'Delete',
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: selected
                ? _Controls(
                    event: event,
                    isFirst: index == 0,
                    onChanged: onChanged,
                    onCommit: _commit,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  static String _summary(StudioEvent e, int index) {
    final at = index == 0 ? '@${e.gapMs}ms' : '+${e.gapMs}ms';
    final base = 'i ${_two(e.intensity)}  s ${_two(e.sharpness)}  $at';
    return e.isTap ? base : '$base  ${e.durationMs}ms';
  }

  static String _two(double v) =>
      v >= 0.995 ? '1.0' : v.toStringAsFixed(2).substring(1);
}

enum _EventAction { duplicate, delete }

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label, {this.color = AppColors.text});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.event,
    required this.isFirst,
    required this.onChanged,
    required this.onCommit,
  });

  final StudioEvent event;
  final bool isFirst;
  final ValueChanged<StudioEvent> onChanged;
  final ValueChanged<StudioEvent> onCommit;

  static double _hundredths(double v) => (v * 100).round() / 100;

  @override
  Widget build(BuildContext context) {
    final e = event;
    // A fixed scale: deriving the max from the value being dragged made the
    // thumb run away from the finger on imported gaps over 500 ms.
    const gapMax = 1000.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 3,
          activeTrackColor: AppColors.studio,
          thumbColor: AppColors.studio,
          overlayColor: AppColors.studio.withValues(alpha: 0.12),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 1),
            const SizedBox(height: 6),
            _SliderRow(
              label: 'Intensity',
              value: e.intensity,
              display: e.intensity.toStringAsFixed(2),
              onChanged: (v) => onChanged(e.copyWith(intensity: _hundredths(v))),
              onChangeEnd: (v) => onCommit(e.copyWith(intensity: _hundredths(v))),
            ),
            _SliderRow(
              label: 'Sharpness',
              value: e.sharpness,
              display: e.sharpness.toStringAsFixed(2),
              onChanged: (v) => onChanged(e.copyWith(sharpness: _hundredths(v))),
              onChangeEnd: (v) => onCommit(e.copyWith(sharpness: _hundredths(v))),
            ),
            if (!e.isTap)
              _SliderRow(
                label: 'Duration',
                value: e.durationMs.toDouble(),
                min: StudioEvent.minDurationMs.toDouble(),
                max: StudioEvent.maxDurationMs.toDouble(),
                display: '${e.durationMs} ms',
                onChanged: (v) => onChanged(e.copyWith(durationMs: _tens(v))),
                onChangeEnd: (v) => onCommit(e.copyWith(durationMs: _tens(v))),
              ),
            _SliderRow(
              label: isFirst ? 'Offset' : 'Gap before',
              value: math.min(e.gapMs, gapMax).toDouble(),
              max: gapMax,
              display: '${e.gapMs} ms',
              onChanged: (v) => onChanged(e.copyWith(gapMs: _fives(v))),
              onChangeEnd: (v) => onCommit(e.copyWith(gapMs: _fives(v))),
            ),
            if (!e.isTap) ...[
              const SizedBox(height: 8),
              const Text('CURVE', style: AppTypography.eyebrow),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final curve in StudioCurve.values)
                    ChoiceChip(
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      selected: e.curve == curve,
                      selectedColor: AppColors.studio.withValues(alpha: 0.2),
                      side: BorderSide(
                        color: e.curve == curve
                            ? AppColors.studio
                            : AppColors.outline,
                      ),
                      avatar: _CurveGlyph(
                        curve: curve,
                        color: e.curve == curve
                            ? AppColors.studio
                            : AppColors.textMuted,
                      ),
                      label: Text(curve.label),
                      onSelected: (_) => onCommit(e.copyWith(curve: curve)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static int _tens(double v) => (v / 10).round() * 10;
  static int _fives(double v) => (v / 5).round() * 5;
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.display,
    required this.onChanged,
    required this.onChangeEnd,
    this.min = 0,
    this.max = 1,
  });

  final String label;
  final double value;
  final String display;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final double min;
  final double max;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.text),
            ),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max).toDouble(),
              min: min,
              max: max,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
          SizedBox(
            width: 58,
            child: Text(
              display,
              textAlign: TextAlign.right,
              style: AppTypography.mono.copyWith(fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tiny drawing of a curve's shape, for the curve chips.
class _CurveGlyph extends StatelessWidget {
  const _CurveGlyph({required this.curve, required this.color});

  final StudioCurve curve;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 12,
      child: CustomPaint(painter: _GlyphPainter(curve: curve, color: color)),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter({required this.curve, required this.color});

  final StudioCurve curve;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final param = curve.toParam(1);
    final path = Path();
    const samples = 16;
    for (var i = 0; i <= samples; i++) {
      final t = i / samples;
      final y = size.height - PatternMath.valueAt(param, t) * size.height;
      final x = t * size.width;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) =>
      oldDelegate.curve != curve || oldDelegate.color != color;
}
