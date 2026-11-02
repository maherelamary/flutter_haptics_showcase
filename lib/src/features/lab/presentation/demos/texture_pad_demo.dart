import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptic_pacer.dart';
import 'package:flutter_haptics_showcase/src/features/lab/domain/lab_patterns.dart';
import 'package:flutter_haptics_showcase/src/features/lab/presentation/widgets/lab_layout.dart';

/// The surfaces you can drag across.
enum PadSurface {
  glass('Glass', Icons.water_drop_outlined),
  sand('Sand', Icons.grain_rounded),
  gravel('Gravel', Icons.scatter_plot_outlined),
  corduroy('Corduroy', Icons.view_week_outlined),
  bubbleWrap('Bubble wrap', Icons.bubble_chart_outlined);

  const PadSurface(this.label, this.icon);

  final String label;
  final IconData icon;

  String get rule => switch (this) {
    PadSurface.glass => 'Almost nothing — a faint tick every 120 px.',
    PadSurface.sand => 'Tiny soft grains every 6 px, randomly weighted.',
    PadSurface.gravel => 'Irregular stones: random spacing, random weight.',
    PadSurface.corduroy =>
      'Crisp ridges every 14 px — sideways only. Slide down: silence.',
    PadSurface.bubbleWrap => 'Each bubble pops once. Find them all.',
  };
}

/// Drag a finger across surfaces that each feel different — texture made of
/// nothing but timing, strength and crispness.
class TexturePadDemo extends StatefulWidget {
  const TexturePadDemo({super.key});

  @override
  State<TexturePadDemo> createState() => _TexturePadDemoState();
}

class _TexturePadDemoState extends State<TexturePadDemo>
    with SingleTickerProviderStateMixin {
  static const _bubbleCols = 6;

  final _random = math.Random();
  final _repaint = ValueNotifier<int>(0);
  late final Ticker _ticker = createTicker(_onTick);

  // Registered handles: each texture fires dozens of times a second.
  final _glass = FlutterHaptics.register(LabPatterns.tap(0.15, 0.95));
  final List<HapticHandle> _sand = [
    for (final p in LabPatterns.ladder(
      count: 3,
      from: 0.15,
      to: 0.25,
      sharpness: 0.2,
    ))
      FlutterHaptics.register(p),
  ];
  final List<HapticHandle> _gravel = [
    for (final p in LabPatterns.ladder(
      count: 5,
      from: 0.3,
      to: 0.9,
      sharpness: 0.6,
    ))
      FlutterHaptics.register(p),
  ];
  final _ridge = FlutterHaptics.register(LabPatterns.tap(0.6, 1.0));
  final _pop = FlutterHaptics.register(LabPatterns.tap(0.95, 1.0));

  // Shared across the handles above. Each handle paces only itself, so
  // without this, switching between them could still fire faster than
  // the actuator can separate.
  final _pacer = HapticPacer(minInterval: const Duration(milliseconds: 30));

  PadSurface _texture = PadSurface.sand;
  final _effects = _PadEffects();
  double _travel = 0;
  double _nextAt = 6;
  int _felt = 0;
  Size _padSize = Size.zero;

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    for (final h in [_glass, ..._sand, ..._gravel, _ridge, _pop]) {
      h.dispose();
    }
    super.dispose();
  }

  void _select(PadSurface texture) {
    if (texture == _texture) return;
    FlutterHaptics.perform(AppHaptics.tick);
    setState(() {
      _texture = texture;
      _travel = 0;
      _nextAt = _spacing();
      // Bubble wrap remembers what was popped, so its counter must too.
      _felt = texture == PadSurface.bubbleWrap ? _effects.popped.length : 0;
    });
    _effects.clear();
    _repaint.value++;
  }

  double _spacing() => switch (_texture) {
    PadSurface.glass => 120,
    PadSurface.sand => 6,
    PadSurface.gravel => 10 + _random.nextDouble() * 20,
    PadSurface.corduroy => 14,
    PadSurface.bubbleWrap => double.infinity,
  };

  void _onTick(Duration _) {
    _repaint.value++;
    if (_effects.idle > const Duration(milliseconds: 900)) _ticker.stop();
  }

  void _wake() {
    _effects.lastActivity = _effects.now;
    if (!_ticker.isActive) _ticker.start();
  }

  void _onDown(Offset p) {
    _wake();
    _effects.trail
      ..clear()
      ..add(_TrailPoint(p, _effects.now));
    if (_texture == PadSurface.bubbleWrap) _popAt(p);
  }

  void _onMove(Offset p, Offset delta) {
    _wake();
    _effects.trail.add(_TrailPoint(p, _effects.now));
    if (_effects.trail.length > 40) _effects.trail.removeAt(0);

    if (_texture == PadSurface.bubbleWrap) {
      _popAt(p);
      return;
    }

    // Corduroy only counts sideways travel: a directional texture.
    _travel += _texture == PadSurface.corduroy
        ? delta.dx.abs()
        : delta.distance;
    if (_travel < _nextAt) return;
    _travel = 0;
    _nextAt = _spacing();

    final handle = switch (_texture) {
      PadSurface.glass => _glass,
      PadSurface.sand => _sand[_random.nextInt(_sand.length)],
      PadSurface.gravel => _gravel[_random.nextInt(_gravel.length)],
      PadSurface.corduroy => _ridge,
      PadSurface.bubbleWrap => _pop,
    };
    if (!_pacer.ready()) return;
    handle.play();
    _effects.sparks.add(_Spark(p, _effects.now));
    setState(() => _felt++);
  }

  void _popAt(Offset p) {
    final layout = _BubbleLayout(_padSize, _bubbleCols);
    final index = layout.indexAt(p);
    if (index == null || _effects.popped.containsKey(index)) return;
    _pop.play();
    _effects.popped[index] = _effects.now;
    setState(() => _felt++);
  }

  void _resetBubbles() {
    FlutterHaptics.perform(AppHaptics.tap);
    _effects.popped.clear();
    _repaint.value++;
    setState(() => _felt = 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubbles = _BubbleLayout(_padSize, _bubbleCols);
    final allPopped =
        _texture == PadSurface.bubbleWrap &&
        bubbles.count > 0 &&
        _effects.popped.length >= bubbles.count;

    return LabLayout(
      hint: _texture.rule,
      status: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: PadSurface.values.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final t = PadSurface.values[i];
            final selected = t == _texture;
            return ChoiceChip(
              selected: selected,
              showCheckmark: false,
              avatar: Icon(
                t.icon,
                size: 16,
                color: selected ? AppColors.lab : AppColors.textMuted,
              ),
              label: Text(t.label),
              selectedColor: AppColors.lab.withValues(alpha: 0.16),
              side: BorderSide(
                color: selected ? AppColors.lab : AppColors.outline,
              ),
              onSelected: (_) => _select(t),
            );
          },
        ),
      ),
      stage: LayoutBuilder(
        builder: (context, constraints) {
          _padSize = constraints.biggest;
          return ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanDown: (d) => _onDown(d.localPosition),
              onPanUpdate: (d) => _onMove(d.localPosition, d.delta),
              child: CustomPaint(
                size: constraints.biggest,
                painter: _TexturePainter(
                  texture: _texture,
                  effects: _effects,
                  bubbleCols: _bubbleCols,
                  repaint: _repaint,
                ),
              ),
            ),
          );
        },
      ),
      controls: Row(
        children: [
          Text(
            '$_felt',
            style: AppTypography.mono.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.lab,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              allPopped
                  ? 'Every bubble popped.'
                  : _texture == PadSurface.bubbleWrap
                  ? 'bubbles popped'
                  : 'grains felt this surface',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (_texture == PadSurface.bubbleWrap)
            OutlinedButton.icon(
              onPressed: _resetBubbles,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Fresh sheet'),
            ),
        ],
      ),
    );
  }
}

class _TrailPoint {
  const _TrailPoint(this.position, this.at);

  final Offset position;
  final Duration at;
}

class _Spark {
  const _Spark(this.position, this.at);

  final Offset position;
  final Duration at;
}

/// Mutable state the painter reads every frame, outside of setState.
class _PadEffects {
  final List<_TrailPoint> trail = [];
  final List<_Spark> sparks = [];
  final Map<int, Duration> popped = {};
  final Stopwatch _clock = Stopwatch()..start();
  Duration lastActivity = Duration.zero;

  /// One clock for every fade, independent of the ticker's start and stop.
  Duration get now => _clock.elapsed;

  Duration get idle => now - lastActivity;

  void clear() {
    trail.clear();
    sparks.clear();
  }
}

/// Where the bubbles sit for a given pad size.
class _BubbleLayout {
  _BubbleLayout(this.size, this.cols)
    : cell = size.width <= 0 ? 0 : size.width / cols,
      rows = size.width <= 0 ? 0 : (size.height / (size.width / cols)).floor();

  final Size size;
  final int cols;
  final double cell;
  final int rows;

  int get count => cols * rows;

  double get _top => (size.height - rows * cell) / 2;

  Offset centerOf(int index) =>
      Offset((index % cols + 0.5) * cell, _top + (index ~/ cols + 0.5) * cell);

  double get radius => cell * 0.36;

  int? indexAt(Offset p) {
    if (cell <= 0) return null;
    final col = (p.dx / cell).floor();
    final row = ((p.dy - _top) / cell).floor();
    if (col < 0 || col >= cols || row < 0 || row >= rows) return null;
    final index = row * cols + col;
    return (p - centerOf(index)).distance <= radius ? index : null;
  }
}

class _TexturePainter extends CustomPainter {
  _TexturePainter({
    required this.texture,
    required this.effects,
    required this.bubbleCols,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final PadSurface texture;
  final _PadEffects effects;
  final int bubbleCols;

  /// Static surfaces are recorded once per size, then replayed each frame;
  /// only the trail and sparks are drawn live.
  static final Map<String, ui.Picture> _cache = {};

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (texture == PadSurface.bubbleWrap) {
      _bubbles(canvas, size);
    } else {
      final key =
          '${texture.name}:${size.width.round()}x${size.height.round()}';
      final picture = _cache.putIfAbsent(key, () {
        final recorder = ui.PictureRecorder();
        final c = Canvas(recorder, rect);
        switch (texture) {
          case PadSurface.glass:
            _glass(c, rect);
          case PadSurface.sand:
            _sand(c, rect);
          case PadSurface.gravel:
            _gravel(c, rect);
          case PadSurface.corduroy:
            _corduroy(c, rect);
          case PadSurface.bubbleWrap:
            break;
        }
        return recorder.endRecording();
      });
      canvas.drawPicture(picture);
    }
    _trail(canvas);
    _sparks(canvas);
  }

  void _glass(Canvas canvas, Rect rect) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E2A30), Color(0xFF101418), Color(0xFF1A2228)],
        ).createShader(rect),
    );
    final streak = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 28;
    for (var i = -2; i < 6; i++) {
      final x = rect.width * i / 4;
      canvas.drawLine(
        Offset(x, rect.bottom),
        Offset(x + rect.height * 0.6, rect.top),
        streak,
      );
    }
  }

  void _sand(Canvas canvas, Rect rect) {
    canvas.drawRect(rect, Paint()..color = const Color(0xFF2A2116));
    final r = math.Random(7);
    final grain = Paint();
    for (var i = 0; i < 2600; i++) {
      final shade = 0.25 + r.nextDouble() * 0.5;
      grain.color = Color.lerp(
        const Color(0xFF6B5638),
        const Color(0xFFD9B98A),
        shade,
      )!.withValues(alpha: 0.5);
      canvas.drawCircle(
        Offset(r.nextDouble() * rect.width, r.nextDouble() * rect.height),
        0.6 + r.nextDouble() * 0.9,
        grain,
      );
    }
  }

  void _gravel(Canvas canvas, Rect rect) {
    canvas.drawRect(rect, Paint()..color = const Color(0xFF17181B));
    final r = math.Random(11);
    for (var i = 0; i < 220; i++) {
      final c = Offset(
        r.nextDouble() * rect.width,
        r.nextDouble() * rect.height,
      );
      final radius = 4 + r.nextDouble() * 11;
      final stone = Rect.fromCircle(center: c, radius: radius);
      canvas.drawOval(
        stone.inflate(r.nextDouble() * 2),
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.5),
            colors: [
              Color.lerp(
                const Color(0xFF8A8A92),
                const Color(0xFFB9B2A6),
                r.nextDouble(),
              )!,
              const Color(0xFF3A3A40),
            ],
          ).createShader(stone),
      );
    }
  }

  void _corduroy(Canvas canvas, Rect rect) {
    canvas.drawRect(rect, Paint()..color = const Color(0xFF3B2416));
    for (double x = 0; x < rect.width; x += 14) {
      final ridge = Rect.fromLTWH(x + 2, 0, 10, rect.height);
      canvas.drawRect(
        ridge,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF4E3020), Color(0xFF8A5634), Color(0xFF4E3020)],
          ).createShader(ridge),
      );
    }
  }

  void _bubbles(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF151B22),
    );
    final layout = _BubbleLayout(size, bubbleCols);
    for (var i = 0; i < layout.count; i++) {
      final c = layout.centerOf(i);
      final poppedAt = effects.popped[i];
      if (poppedAt == null) {
        final rect = Rect.fromCircle(center: c, radius: layout.radius);
        canvas.drawCircle(
          c,
          layout.radius,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.35, -0.45),
              colors: [
                Colors.white.withValues(alpha: 0.35),
                const Color(0xFF7AA7FF).withValues(alpha: 0.12),
              ],
            ).createShader(rect),
        );
        canvas.drawCircle(
          c,
          layout.radius,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.18)
            ..style = PaintingStyle.stroke,
        );
      } else {
        // Flattened plastic, plus a burst ring for the first 300 ms.
        canvas.drawCircle(
          c,
          layout.radius * 0.8,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.05)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        final age = (effects.now - poppedAt).inMilliseconds / 300;
        if (age >= 0 && age < 1) {
          canvas.drawCircle(
            c,
            layout.radius * (1 + age * 0.8),
            Paint()
              ..color = AppColors.lab.withValues(alpha: (1 - age) * 0.9)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3,
          );
        }
      }
    }
  }

  void _trail(Canvas canvas) {
    final points = effects.trail;
    for (var i = 1; i < points.length; i++) {
      final age = (effects.now - points[i].at).inMilliseconds / 600;
      if (age >= 1) continue;
      canvas.drawLine(
        points[i - 1].position,
        points[i].position,
        Paint()
          ..color = AppColors.lab.withValues(
            alpha: (1 - age.clamp(0.0, 1.0)) * 0.7,
          )
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3),
      );
    }
  }

  void _sparks(Canvas canvas) {
    effects.sparks.removeWhere(
      (s) => (effects.now - s.at).inMilliseconds > 400,
    );
    for (final s in effects.sparks) {
      final age = ((effects.now - s.at).inMilliseconds / 400).clamp(0.0, 1.0);
      canvas.drawCircle(
        s.position,
        3 + age * 10,
        Paint()
          ..color = AppColors.lab.withValues(alpha: (1 - age) * 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_TexturePainter oldDelegate) =>
      oldDelegate.texture != texture;
}
