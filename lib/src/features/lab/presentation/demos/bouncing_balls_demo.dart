import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptic_pacer.dart';
import 'package:flutter_haptics_showcase/src/features/lab/domain/lab_patterns.dart';
import 'package:flutter_haptics_showcase/src/features/lab/presentation/widgets/lab_layout.dart';

/// What a ball is made of: how it bounces and how its impacts feel.
enum BallMaterial {
  rubber('Rubber', 0.82, 1, 0.2, AppColors.lab),
  steel('Steel', 0.58, 3, 0.95, Color(0xFFC9D2E0));

  const BallMaterial(
    this.label,
    this.restitution,
    this.mass,
    this.sharpness,
    this.color,
  );

  final String label;
  final double restitution;
  final double mass;

  /// Rubber thuds, steel clinks: the same physics, a different sharpness.
  final double sharpness;
  final Color color;
}

class _Ball {
  _Ball(this.position, this.velocity, this.material)
    : radius = material == BallMaterial.steel ? 20 : 26;

  Offset position;
  Offset velocity;
  final BallMaterial material;
  final double radius;
  double flash = 0;
}

/// Tap to drop balls. Every impact is felt at a strength proportional to
/// its speed — haptics as a physical property, not a notification.
class BouncingBallsDemo extends StatefulWidget {
  const BouncingBallsDemo({super.key});

  @override
  State<BouncingBallsDemo> createState() => _BouncingBallsDemoState();
}

class _BouncingBallsDemoState extends State<BouncingBallsDemo>
    with SingleTickerProviderStateMixin {
  static const _gravity = 1900.0;
  static const _maxBalls = 8;

  /// Below this impact speed (px/s) a bounce is silent: settling balls
  /// should not buzz.
  static const _silentBelow = 140.0;
  static const _fullAt = 2200.0;

  final List<_Ball> _balls = [];
  final _random = math.Random();
  final _repaint = ValueNotifier<int>(0);
  late final Ticker _ticker = createTicker(_step);

  /// Five prepared strengths per material: impacts quantise to the nearest.
  final Map<BallMaterial, List<HapticHandle>> _impacts = {
    for (final m in BallMaterial.values)
      m: [
        for (final p in LabPatterns.ladder(
          count: 5,
          from: 0.2,
          to: 1.0,
          sharpness: m.sharpness,
        ))
          FlutterHaptics.register(p),
      ],
  };

  /// One pacer for the whole world: a pile of balls must not become a buzz.
  /// Each handle paces only itself, so with one per material and strength,
  /// only a shared pacer keeps the total rate below what the actuator can
  /// separate.
  final _pacer = HapticPacer(minInterval: const Duration(milliseconds: 35));

  BallMaterial _material = BallMaterial.rubber;
  Size _size = Size.zero;
  Duration _last = Duration.zero;
  int _stillFrames = 0;
  double _lastImpact = 0;
  int _impactsFelt = 0;
  bool _statusDirty = false;

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    for (final list in _impacts.values) {
      for (final h in list) {
        h.dispose();
      }
    }
    super.dispose();
  }

  void _spawn(Offset at) {
    // setState so the hint hides and Clear enables right away, not at the
    // first loud impact.
    setState(() {
      if (_balls.length >= _maxBalls) _balls.removeAt(0);
      _balls.add(
        _Ball(
          at,
          Offset(
            (_random.nextDouble() - 0.5) * 500,
            -_random.nextDouble() * 200,
          ),
          _material,
        ),
      );
    });
    _stillFrames = 0;
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _clear() {
    FlutterHaptics.perform(AppHaptics.tap);
    setState(_balls.clear);
    _repaint.value++;
  }

  void _impact(double speed, BallMaterial material) {
    if (speed < _silentBelow || !_pacer.ready()) return;
    final strength = ((speed - _silentBelow) / (_fullAt - _silentBelow)).clamp(
      0.1,
      1.0,
    );
    final ladder = _impacts[material]!;
    ladder[(strength * (ladder.length - 1)).round()].play();
    _lastImpact = strength;
    _impactsFelt++;
    _statusDirty = true;
  }

  void _step(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 1 / 30);
    _last = elapsed;
    if (_size.isEmpty) return;
    final before = [for (final b in _balls) b.position];

    for (final b in _balls) {
      b.velocity += Offset(0, _gravity * dt);
      b.position += b.velocity * dt;
      b.flash = math.max(0, b.flash - dt * 4);

      // Floor.
      final floor = _size.height - b.radius;
      if (b.position.dy > floor) {
        final speed = b.velocity.dy.abs();
        b.position = Offset(b.position.dx, floor);
        b.velocity = Offset(
          b.velocity.dx * 0.92,
          -b.velocity.dy * b.material.restitution,
        );
        if (speed > _silentBelow) b.flash = 1;
        _impact(speed, b.material);
        if (b.velocity.dy.abs() < 60) {
          b.velocity = Offset(b.velocity.dx * 0.96, 0);
        }
      }
      // Walls.
      if (b.position.dx < b.radius || b.position.dx > _size.width - b.radius) {
        final speed = b.velocity.dx.abs();
        b.position = Offset(
          b.position.dx.clamp(b.radius, _size.width - b.radius),
          b.position.dy,
        );
        b.velocity = Offset(
          -b.velocity.dx * b.material.restitution,
          b.velocity.dy,
        );
        if (speed > _silentBelow) b.flash = 1;
        _impact(speed, b.material);
      }
    }

    // Ball against ball.
    for (var i = 0; i < _balls.length; i++) {
      for (var j = i + 1; j < _balls.length; j++) {
        _collide(_balls[i], _balls[j]);
      }
    }

    _repaint.value++;
    // A ball resting on another never reaches the floor (and gravity keeps
    // nudging its velocity), so "settled" means nothing has *moved* more
    // than a fraction of a pixel per frame for half a second.
    var moved = 0.0;
    for (var i = 0; i < _balls.length; i++) {
      moved = math.max(moved, (_balls[i].position - before[i]).distance);
    }
    final still = moved < 0.4;
    _stillFrames = still ? _stillFrames + 1 : 0;
    if (_stillFrames > 30) _ticker.stop();
    // Rebuild the readout only when something was felt; the world itself
    // repaints through the notifier without rebuilding widgets.
    if (_statusDirty && mounted) {
      _statusDirty = false;
      setState(() {});
    }
  }

  void _collide(_Ball a, _Ball b) {
    final delta = b.position - a.position;
    final dist = delta.distance;
    final minDist = a.radius + b.radius;
    if (dist == 0 || dist >= minDist) return;

    final n = delta / dist;
    final relative = b.velocity - a.velocity;
    final approach = relative.dx * n.dx + relative.dy * n.dy;

    // Push apart in proportion to mass.
    final overlap = minDist - dist;
    final total = a.material.mass + b.material.mass;
    a.position -= n * (overlap * b.material.mass / total);
    b.position += n * (overlap * a.material.mass / total);

    if (approach >= 0) return;
    final e = math.min(a.material.restitution, b.material.restitution);
    final j = -(1 + e) * approach / (1 / a.material.mass + 1 / b.material.mass);
    a.velocity -= n * (j / a.material.mass);
    b.velocity += n * (j / b.material.mass);

    final speed = -approach;
    if (speed > _silentBelow) {
      a.flash = 1;
      b.flash = 1;
    }
    // The harder material decides the feel of the contact.
    _impact(
      speed,
      a.material.sharpness >= b.material.sharpness ? a.material : b.material,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LabLayout(
      hint:
          'Tap anywhere to drop a ball. Hard impacts hit hard; settling '
          'bounces fall silent. Steel clinks, rubber thuds.',
      status: Row(
        children: [
          const Text('LAST IMPACT', style: AppTypography.eyebrow),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: _lastImpact,
                minHeight: 6,
                color: _material.color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$_impactsFelt felt',
            style: AppTypography.mono.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
      stage: LabPanel(
        child: LayoutBuilder(
          builder: (context, constraints) {
            _size = constraints.biggest;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _spawn(d.localPosition),
              child: CustomPaint(
                size: constraints.biggest,
                painter: _WorldPainter(balls: _balls, repaint: _repaint),
                child: _balls.isEmpty
                    ? Center(
                        child: Text(
                          'Tap to drop',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: AppColors.textFaint),
                        ),
                      )
                    : null,
              ),
            );
          },
        ),
      ),
      controls: Row(
        children: [
          Expanded(
            child: SegmentedButton<BallMaterial>(
              showSelectedIcon: false,
              segments: [
                for (final m in BallMaterial.values)
                  ButtonSegment(value: m, label: Text(m.label)),
              ],
              selected: {_material},
              onSelectionChanged: (s) {
                FlutterHaptics.perform(AppHaptics.tick);
                setState(() => _material = s.first);
              },
            ),
          ),
          const SizedBox(width: 12),
          IconButton.outlined(
            tooltip: 'Clear',
            onPressed: _balls.isEmpty ? null : _clear,
            icon: const Icon(Icons.delete_sweep_rounded),
          ),
        ],
      ),
    );
  }
}

class _WorldPainter extends CustomPainter {
  _WorldPainter({required this.balls, required Listenable repaint})
    : super(repaint: repaint);

  final List<_Ball> balls;

  @override
  void paint(Canvas canvas, Size size) {
    // A faint grid and floor line give the motion something to read against.
    final grid = Paint()
      ..color = AppColors.outline.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (double y = 40; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      Paint()
        ..color = AppColors.lab.withValues(alpha: 0.5)
        ..strokeWidth = 2,
    );

    for (final b in balls) {
      final c = b.material.color;
      if (b.flash > 0) {
        canvas.drawCircle(
          b.position,
          b.radius * (1.2 + (1 - b.flash) * 0.8),
          Paint()
            ..color = c.withValues(alpha: b.flash * 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      canvas.drawCircle(
        b.position,
        b.radius * 1.15,
        Paint()
          ..color = c.withValues(alpha: 0.18 + 0.3 * b.flash)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      final rect = Rect.fromCircle(center: b.position, radius: b.radius);
      canvas.drawCircle(
        b.position,
        b.radius,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.4),
            colors: b.material == BallMaterial.steel
                ? [Colors.white, c, const Color(0xFF4A5260)]
                : [const Color(0xFFFFB38F), c, const Color(0xFF8A3A1A)],
            stops: const [0, 0.45, 1],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_WorldPainter oldDelegate) => true;
}
