import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_patterns.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/safe_animated_switcher.dart';

/// A media scrubber that is silent between chapters and ticks at their
/// boundaries — structure you can feel without watching the bar.
class ChapterScrubberDemo extends StatefulWidget {
  const ChapterScrubberDemo({super.key});

  @override
  State<ChapterScrubberDemo> createState() => _ChapterScrubberDemoState();
}

class _ChapterScrubberDemoState extends State<ChapterScrubberDemo> {
  static const _length = 240.0;
  static const _chapters = <(double, String)>[
    (0, 'Cold open'),
    (38, 'The problem'),
    (95, 'First prototype'),
    (150, 'Field test'),
    (201, 'What we learned'),
  ];

  // Paced by the handle itself: a fast scrub across two close chapters
  // stays two ticks rather than one smeared one.
  final HapticHandle _boundary = FlutterHaptics.register(AppPatterns.fineDetent);

  double _position = 62;
  bool _dragging = false;
  int _felt = 0;

  int _chapterAt(double seconds) {
    var index = 0;
    for (var i = 0; i < _chapters.length; i++) {
      if (seconds >= _chapters[i].$1) index = i;
    }
    return index;
  }

  void _seek(double dx, double width) {
    if (width <= 0) return;
    final next = (dx / width * _length).clamp(0.0, _length);
    // One tick per boundary crossed, never one per second scrubbed.
    if (_chapterAt(next) != _chapterAt(_position)) _cross();
    setState(() => _position = next);
  }

  Future<void> _cross() async {
    final route = await _boundary.play();
    if (mounted && route != HapticRoute.none) setState(() => _felt++);
  }

  static String _clock(double seconds) {
    final s = seconds.round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _boundary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chapter = _chapterAt(_position);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFFC792FF), Color(0xFF7AA7FF)],
                ),
              ),
              child: const Icon(
                Icons.podcasts_rounded,
                color: AppColors.onAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ep. 12 · Feeling the interface',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  SafeAnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      'Ch. ${chapter + 1} · ${_chapters[chapter].$2}',
                      key: ValueKey(chapter),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.studio,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _seek(d.localPosition.dx, width),
              onHorizontalDragStart: (d) {
                setState(() => _dragging = true);
                _seek(d.localPosition.dx, width);
              },
              onHorizontalDragUpdate: (d) =>
                  _seek(d.localPosition.dx, width),
              // Letting go is silent: the position is the result.
              onHorizontalDragEnd: (_) => setState(() => _dragging = false),
              child: SizedBox(
                height: 44,
                width: width,
                child: CustomPaint(
                  painter: _ScrubberPainter(
                    position: _position / _length,
                    boundaries: [
                      for (final c in _chapters.skip(1)) c.$1 / _length,
                    ],
                    dragging: _dragging,
                  ),
                ),
              ),
            );
          },
        ),
        Row(
          children: [
            Text(
              _clock(_position),
              style: AppTypography.mono.copyWith(
                fontSize: 11,
                color: AppColors.text,
              ),
            ),
            const Spacer(),
            Text(
              'boundaries felt: $_felt',
              style: AppTypography.mono.copyWith(
                fontSize: 10.5,
                color: AppColors.textMuted,
              ),
            ),
            const Spacer(),
            Text(
              _clock(_length),
              style: AppTypography.mono.copyWith(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ScrubberPainter extends CustomPainter {
  _ScrubberPainter({
    required this.position,
    required this.boundaries,
    required this.dragging,
  });

  /// 0.0–1.0.
  final double position;

  /// Chapter starts after the first, 0.0–1.0.
  final List<double> boundaries;
  final bool dragging;

  static const _gap = 3.0;
  static const _inset = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final span = size.width - _inset * 2;
    final thickness = dragging ? 8.0 : 5.0;
    final edges = [0.0, ...boundaries, 1.0];
    final playedX = _inset + span * position;

    for (var i = 0; i < edges.length - 1; i++) {
      final x0 = _inset + span * edges[i] + (i == 0 ? 0 : _gap / 2);
      final x1 = _inset + span * edges[i + 1] -
          (i == edges.length - 2 ? 0 : _gap / 2);
      final segment = RRect.fromLTRBR(
        x0,
        cy - thickness / 2,
        x1,
        cy + thickness / 2,
        Radius.circular(thickness / 2),
      );
      canvas.drawRRect(segment, Paint()..color = AppColors.surfaceHighest);
      if (playedX > x0) {
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(x0, 0, playedX, size.height));
        canvas.drawRRect(segment, Paint()..color = AppColors.studio);
        canvas.restore();
      }
    }

    final r = dragging ? 11.0 : 8.0;
    canvas.drawCircle(
      Offset(playedX, cy),
      r + 6,
      Paint()..color = AppColors.studio.withValues(alpha: dragging ? 0.2 : 0),
    );
    canvas.drawCircle(Offset(playedX, cy), r, Paint()..color = AppColors.text);
  }

  @override
  bool shouldRepaint(_ScrubberPainter oldDelegate) =>
      oldDelegate.position != position || oldDelegate.dragging != dragging;
}
