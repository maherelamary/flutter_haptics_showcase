import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_patterns.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/haptic_echo.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/pattern_waveform.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/safe_animated_switcher.dart';
import 'package:flutter_haptics_showcase/src/features/lab/domain/lab_patterns.dart';
import 'package:flutter_haptics_showcase/src/features/lab/presentation/widgets/lab_layout.dart';

/// A rattle generated fresh for every throw, then a landing thud.
class DiceRollDemo extends StatefulWidget {
  const DiceRollDemo({super.key});

  @override
  State<DiceRollDemo> createState() => _DiceRollDemoState();
}

class _DiceRollDemoState extends State<DiceRollDemo>
    with SingleTickerProviderStateMixin {
  final _random = math.Random();
  late final AnimationController _roll = AnimationController(vsync: this)
    ..addListener(_onFrame)
    ..addStatusListener(_onStatus);

  int _a = 5;
  int _b = 2;
  bool _rolling = false;
  bool _shaking = false;
  bool _doubles = false;
  int _celebrations = 0;
  Timer? _shake;
  Timer? _coin;

  HapticPattern? _pattern;
  List<int> _tapTimes = const [];
  int _nextTap = 0;
  int _landingMs = 0;
  double _spin = 0;

  /// Taps that start close together and spread out, like a die losing
  /// energy: 35 ms apart at first, each gap 18% longer than the last.
  (HapticPattern, List<int>) _rattle() {
    final builder = HapticPatternBuilder();
    final times = <int>[];
    var t = 0.0;
    var gap = 35.0;
    while (t < 650) {
      times.add(t.round());
      builder.tap(
        intensity: 0.35 + _random.nextDouble() * 0.4,
        sharpness: 0.7 + _random.nextDouble() * 0.3,
      );
      // tap() already advances 25 ms; wait out the rest of the gap.
      builder.waitMs(
        math.max(0, (gap - HapticEvent.transientWidth.inMilliseconds).round()),
      );
      t += gap;
      gap *= 1.18;
    }
    return (builder.build(), times);
  }

  void _throw() {
    if (_rolling) return;
    _shake?.cancel();
    _coin?.cancel();
    final (rattle, times) = _rattle();
    final full = rattle.then(AppPatterns.thud);
    setState(() {
      _rolling = true;
      _shaking = false;
      _doubles = false;
      _pattern = full;
      _tapTimes = times;
      _nextTap = 0;
      _landingMs = rattle.duration.inMilliseconds;
    });
    // One call: rattle and thud are a single timeline, so they cannot drift.
    FlutterHaptics.play(full);
    _roll
      ..duration = full.duration
      ..forward(from: 0);
  }

  void _onFrame() {
    final elapsed = _roll.value * _roll.duration!.inMilliseconds;
    var changed = false;
    while (_nextTap < _tapTimes.length && _tapTimes[_nextTap] <= elapsed) {
      _nextTap++;
      _a = _random.nextInt(6) + 1;
      _b = _random.nextInt(6) + 1;
      changed = true;
    }
    final towardLanding = (elapsed / math.max(1, _landingMs)).clamp(0.0, 1.0);
    final spin = math.pow(1 - towardLanding, 2) * math.pi * 3;
    if (changed || spin != _spin) setState(() => _spin = spin.toDouble());
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final doubles = _a == _b;
    setState(() {
      _rolling = false;
      _doubles = doubles;
    });
    if (doubles) {
      _coin = Timer(const Duration(milliseconds: 150), () {
        FlutterHaptics.play(AppPatterns.coin);
        if (mounted) setState(() => _celebrations++);
      });
    }
  }

  /// The hold was taken away (Control Center, a call): stop rattling,
  /// don't throw.
  void _cancelShake() {
    _shake?.cancel();
    if (mounted && _shaking) setState(() => _shaking = false);
  }

  void _startShake() {
    if (_rolling) return;
    _shake?.cancel();
    setState(() => _shaking = true);
    void rattle() {
      FlutterHaptics.play(
        LabPatterns.tap(0.25 + _random.nextDouble() * 0.25, 0.8),
      );
      if (mounted) {
        setState(() {
          _a = _random.nextInt(6) + 1;
          _b = _random.nextInt(6) + 1;
          _spin = (_random.nextDouble() - 0.5) * 0.4;
        });
      }
      if (!mounted || !_shaking) return;
      _shake = Timer(Duration(milliseconds: 55 + _random.nextInt(45)), rattle);
    }

    rattle();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The tab shell keeps this page alive offstage with its tickers muted,
    // but the shake and coin Timers and a playing rattle are not tickers.
    if (!TickerMode.valuesOf(context).enabled) {
      _shake?.cancel();
      _coin?.cancel();
      _shaking = false;
      if (_rolling) FlutterHaptics.stop();
    }
  }

  @override
  void dispose() {
    _shake?.cancel();
    _coin?.cancel();
    _roll.dispose();
    if (_rolling) FlutterHaptics.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pattern = _pattern;
    return LabLayout(
      hint:
          'Tap Roll, or hold it to shake the dice in your hand and let go '
          'to throw. Every rattle is generated fresh.',
      stage: LabPanel(
        glow: _doubles ? AppColors.accent : AppColors.lab,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HapticEcho(
              trigger: _celebrations,
              color: AppColors.accent,
              spread: 1.5,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(32),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Die(value: _a, angle: _spin, glow: _doubles),
                    const SizedBox(width: 24),
                    _Die(value: _b, angle: -_spin * 1.3, glow: _doubles),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SafeAnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _rolling || _shaking
                    ? '···'
                    : _doubles
                    ? 'Doubles!'
                    : '${_a + _b}',
                key: ValueKey('$_rolling$_shaking$_doubles${_a + _b}'),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: _doubles ? AppColors.accent : AppColors.text,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pattern == null
                        ? 'GENERATED RATTLE'
                        : 'GENERATED RATTLE · ${_tapTimes.length} TAPS + THUD · '
                              '${pattern.duration.inMilliseconds}MS',
                    style: AppTypography.eyebrow,
                  ),
                  const SizedBox(height: 8),
                  PatternWaveform(
                    pattern: pattern ?? HapticPattern.empty,
                    color: AppColors.lab,
                    height: 44,
                    minDuration: const Duration(milliseconds: 800),
                    progress: _rolling ? _roll.value : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      controls: GestureDetector(
        onLongPressStart: (_) => _startShake(),
        onLongPressEnd: (_) => _throw(),
        onLongPressCancel: _cancelShake,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.lab,
            foregroundColor: AppColors.onAccent,
          ),
          onPressed: _rolling ? null : _throw,
          icon: const Icon(Icons.casino_rounded),
          label: Text(_shaking ? 'Let go to throw' : 'Roll'),
        ),
      ),
    );
  }
}

class _Die extends StatelessWidget {
  const _Die({required this.value, required this.angle, required this.glow});

  final int value;
  final double angle;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7F3EA), Color(0xFFCFC8B8)],
          ),
          boxShadow: [
            BoxShadow(
              color: glow
                  ? AppColors.accent.withValues(alpha: 0.6)
                  : Colors.black.withValues(alpha: 0.5),
              blurRadius: glow ? 28 : 16,
              offset: glow ? Offset.zero : const Offset(0, 8),
            ),
          ],
        ),
        child: CustomPaint(painter: _PipPainter(value)),
      ),
    );
  }
}

class _PipPainter extends CustomPainter {
  _PipPainter(this.value);

  final int value;

  static const _layouts = <int, List<(double, double)>>{
    1: [(0.5, 0.5)],
    2: [(0.27, 0.27), (0.73, 0.73)],
    3: [(0.27, 0.27), (0.5, 0.5), (0.73, 0.73)],
    4: [(0.27, 0.27), (0.73, 0.27), (0.27, 0.73), (0.73, 0.73)],
    5: [(0.27, 0.27), (0.73, 0.27), (0.5, 0.5), (0.27, 0.73), (0.73, 0.73)],
    6: [
      (0.27, 0.25),
      (0.73, 0.25),
      (0.27, 0.5),
      (0.73, 0.5),
      (0.27, 0.75),
      (0.73, 0.75),
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final pip = Paint()..color = const Color(0xFF1B1B20);
    for (final (x, y) in _layouts[value] ?? const <(double, double)>[]) {
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        size.width * (value == 1 ? 0.11 : 0.085),
        pip,
      );
    }
  }

  @override
  bool shouldRepaint(_PipPainter oldDelegate) => oldDelegate.value != value;
}
