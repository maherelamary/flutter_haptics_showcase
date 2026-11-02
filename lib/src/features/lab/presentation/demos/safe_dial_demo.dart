import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_patterns.dart';
import 'package:flutter_haptics_showcase/src/features/lab/domain/lab_patterns.dart';
import 'package:flutter_haptics_showcase/src/features/lab/presentation/widgets/lab_layout.dart';

/// A combination dial you crack by feel: every number clicks, and the right
/// one clicks differently.
class SafeDialDemo extends StatefulWidget {
  const SafeDialDemo({super.key});

  static const numbers = 40;

  /// How long to rest on a number for it to count.
  static const dwell = Duration(milliseconds: 450);

  @override
  State<SafeDialDemo> createState() => _SafeDialDemoState();
}

class _SafeDialDemoState extends State<SafeDialDemo>
    with SingleTickerProviderStateMixin {
  static const _step = 2 * math.pi / SafeDialDemo.numbers;

  /// Every ordinary number: fine and crisp. Paced, because a fast spin
  /// passes numbers quicker than the actuator can separate them.
  final _click = FlutterHaptics.register(
    LabPatterns.tap(0.35, 0.9),
    minInterval: const Duration(milliseconds: 25),
  );

  /// The right number: heavier and duller. Different enough to notice,
  /// similar enough that you have to pay attention. Never paced away — it
  /// is the whole point — and a separate handle, so a click just before it
  /// cannot hold it back.
  final _tumbler = FlutterHaptics.register(
    LabPatterns.tap(0.8, 0.3),
    minInterval: Duration.zero,
  );
  final _random = math.Random();

  late final AnimationController _door = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  late List<int> _combination = _newCombination();
  double _angle = 0;
  double? _grabAngle;
  int _number = 0;
  int _found = 0;
  bool _reveal = false;
  Timer? _dwell;

  List<int> _newCombination() {
    final picks = <int>{};
    while (picks.length < 3) {
      // Never 0: the dial starts there, so it would open without a turn.
      final n = 1 + _random.nextInt(SafeDialDemo.numbers - 1);
      // Keep numbers apart around the dial, so each one takes a real turn
      // to reach — 2 and 38 are four apart on a 40-number dial, not 36.
      bool apart(int p) {
        final d = (p - n).abs();
        return math.min(d, SafeDialDemo.numbers - d) > 6;
      }

      if (picks.every(apart)) picks.add(n);
    }
    return picks.toList();
  }

  bool get _open => _found >= _combination.length;

  int _numberAt(double angle) {
    final n = (-angle / _step).round() % SafeDialDemo.numbers;
    return n < 0 ? n + SafeDialDemo.numbers : n;
  }

  double _touchAngle(Offset local, Size size) {
    final c = size.center(Offset.zero);
    return math.atan2(local.dy - c.dy, local.dx - c.dx);
  }

  void _onPanStart(DragStartDetails d, Size size) {
    if (_open) return;
    _grabAngle = _touchAngle(d.localPosition, size);
  }

  void _onPanUpdate(DragUpdateDetails d, Size size) {
    final grab = _grabAngle;
    if (_open || grab == null) return;
    final now = _touchAngle(d.localPosition, size);
    var delta = now - grab;
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta < -math.pi) delta += 2 * math.pi;
    _grabAngle = now;

    final angle = _angle + delta;
    final number = _numberAt(angle);
    if (number != _number) _onNumber(number);
    setState(() => _angle = angle);
  }

  void _onPanEnd(DragEndDetails _) => _grabAngle = null;

  void _onNumber(int number) {
    _number = number;
    _dwell?.cancel();
    final target = _combination[_found];
    if (number == target) {
      _tumbler.play();
      _dwell = Timer(SafeDialDemo.dwell, _lockIn);
    } else {
      _click.play();
    }
  }

  void _lockIn() {
    if (!mounted || _open) return;
    setState(() => _found++);
    if (_open) {
      FlutterHaptics.play(AppPatterns.lock);
      _door.forward();
    } else {
      FlutterHaptics.play(AppPatterns.coin);
    }
  }

  void _reset() {
    FlutterHaptics.perform(AppHaptics.tap);
    _dwell?.cancel();
    _door.value = 0;
    setState(() {
      _combination = _newCombination();
      _found = 0;
      _angle = 0;
      _number = 0;
    });
  }

  @override
  void dispose() {
    _dwell?.cancel();
    _door.dispose();
    _click.dispose();
    _tumbler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LabLayout(
      hint:
          'Turn the dial. Every number clicks; the right one lands '
          'heavier. Rest on it for a moment to set it.',
      status: Row(
        children: [
          for (var i = 0; i < _combination.length; i++) ...[
            _Slot(
              value: _reveal || i < _found ? _combination[i] : null,
              found: i < _found,
              current: i == _found && !_open,
            ),
            const SizedBox(width: 8),
          ],
          const Spacer(),
          IconButton(
            tooltip: _reveal ? 'Hide combination' : 'Reveal combination',
            onPressed: () {
              FlutterHaptics.perform(AppHaptics.tap);
              setState(() => _reveal = !_reveal);
            },
            icon: Icon(
              _reveal ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
      stage: LabPanel(
        glow: _open ? AppColors.accent : AppColors.lab,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side =
                math.min(constraints.maxWidth, constraints.maxHeight) - 32;
            final size = Size.square(side);
            return Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Behind the door.
                  AnimatedBuilder(
                    animation: _door,
                    builder: (context, _) => Opacity(
                      opacity: _door.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_open_rounded,
                            size: 56,
                            color: AppColors.accent,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Unlocked',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _door,
                    builder: (context, child) {
                      final t = Curves.easeInOutCubic.transform(_door.value);
                      return Opacity(
                        opacity: (1 - t * 1.2).clamp(0.0, 1.0),
                        child: Transform(
                          alignment: Alignment.centerLeft,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.0012)
                            ..rotateY(-t * 1.3),
                          child: child,
                        ),
                      );
                    },
                    child: GestureDetector(
                      onPanStart: (d) => _onPanStart(d, size),
                      onPanUpdate: (d) => _onPanUpdate(d, size),
                      onPanEnd: _onPanEnd,
                      child: CustomPaint(
                        size: size,
                        painter: _DialPainter(
                          angle: _angle,
                          number: _number,
                          open: _open,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      controls: Row(
        children: [
          Text(
            _number.toString().padLeft(2, '0'),
            style: AppTypography.mono.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(width: 10),
          // Takes the slack, and gives it up first on a narrow phone.
          const Expanded(
            child: Text(
              'UNDER THE MARK',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.eyebrow,
            ),
          ),
          OutlinedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('New combo'),
          ),
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.value,
    required this.found,
    required this.current,
  });

  final int? value;
  final bool found;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final color = found
        ? AppColors.accent
        : current
        ? AppColors.lab
        : AppColors.outlineStrong;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 48,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: found
            ? AppColors.accent.withValues(alpha: 0.12)
            : AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        value == null ? '··' : value.toString().padLeft(2, '0'),
        style: AppTypography.mono.copyWith(
          fontWeight: FontWeight.w700,
          color: found ? AppColors.accent : AppColors.textMuted,
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.angle, required this.number, required this.open});

  final double angle;
  final int number;
  final bool open;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    const step = 2 * math.pi / SafeDialDemo.numbers;

    // Body.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFF34343E), Color(0xFF16161B)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = AppColors.outlineStrong
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Ticks and numbers, rotating with the dial.
    for (var i = 0; i < SafeDialDemo.numbers; i++) {
      final a = -math.pi / 2 + i * step + angle;
      final major = i % 5 == 0;
      final outer = c + Offset(math.cos(a), math.sin(a)) * (r - 8);
      final inner =
          c + Offset(math.cos(a), math.sin(a)) * (r - (major ? 24 : 16));
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color = i == number
              ? AppColors.lab
              : (major ? AppColors.text : AppColors.textFaint)
          ..strokeWidth = major ? 2.4 : 1.4
          ..strokeCap = StrokeCap.round,
      );
      if (major) {
        final label = TextPainter(
          text: TextSpan(
            text: '$i',
            style: AppTypography.mono.copyWith(
              fontSize: r * 0.09,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final p = c + Offset(math.cos(a), math.sin(a)) * (r - 44);
        label.paint(canvas, p - Offset(label.width / 2, label.height / 2));
      }
    }

    // Grip ring and hub.
    canvas.drawCircle(
      c,
      r * 0.52,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.25, -0.35),
          colors: [Color(0xFF4A4A56), Color(0xFF202027)],
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.52)),
    );
    for (var i = 0; i < 24; i++) {
      final a = i * math.pi / 12 + angle;
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * r * 0.42,
        c + Offset(math.cos(a), math.sin(a)) * r * 0.5,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..strokeWidth = 3,
      );
    }
    canvas.drawCircle(
      c,
      r * 0.16,
      Paint()
        ..color = open
            ? AppColors.accent
            : AppColors.lab.withValues(alpha: 0.9),
    );

    // The fixed mark at the top.
    final mark = Path()
      ..moveTo(c.dx, c.dy - r + 2)
      ..lineTo(c.dx - 9, c.dy - r - 12)
      ..lineTo(c.dx + 9, c.dy - r - 12)
      ..close();
    canvas.drawPath(
      mark,
      Paint()
        ..color = AppColors.lab
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4),
    );
  }

  @override
  bool shouldRepaint(_DialPainter oldDelegate) =>
      oldDelegate.angle != angle ||
      oldDelegate.number != number ||
      oldDelegate.open != open;
}
