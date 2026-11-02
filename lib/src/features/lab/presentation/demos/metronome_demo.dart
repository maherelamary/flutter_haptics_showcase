import 'dart:async';
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

enum _Meter {
  fourFour('4/4', 4, {0}),
  threeFour('3/4', 3, {0}),
  sixEight('6/8', 6, {0});

  const _Meter(this.label, this.beats, this.accents);

  final String label;
  final int beats;
  final Set<int> accents;

  /// 6/8 has a secondary accent on beat four.
  bool isSecondary(int beat) => this == _Meter.sixEight && beat == 3;
}

/// A metronome you can feel in your pocket. Prepared handles and a
/// drift-corrected clock keep the beat honest.
class MetronomeDemo extends StatefulWidget {
  const MetronomeDemo({super.key});

  static const minBpm = 40;
  static const maxBpm = 220;

  @override
  State<MetronomeDemo> createState() => _MetronomeDemoState();
}

class _MetronomeDemoState extends State<MetronomeDemo>
    with SingleTickerProviderStateMixin {
  // Beats opt out of pacing: they are already scheduled on the clock, and a
  // metronome that drops a beat is broken, whatever the actuator thinks.
  final _accent = FlutterHaptics.register(
    LabPatterns.tap(1.0, 0.9),
    minInterval: Duration.zero,
  );
  final _secondary = FlutterHaptics.register(
    LabPatterns.tap(0.7, 0.75),
    minInterval: Duration.zero,
  );
  final _beat = FlutterHaptics.register(
    LabPatterns.tap(0.45, 0.6),
    minInterval: Duration.zero,
  );

  // The tempo slider performs an intent, which a handle cannot hold yet, so
  // it still needs a pacer of its own.
  final _sliderPacer = HapticPacer(
    minInterval: const Duration(milliseconds: 45),
  );

  final Stopwatch _clock = Stopwatch()..start();
  final _frame = ValueNotifier<int>(0);
  late final Ticker _ticker = createTicker((_) => _frame.value++);

  // In the background the timer is throttled or frozen and no beat is felt,
  // so a hidden metronome stops instead of claiming to run; Start begins
  // again on a fresh anchor. Not on `inactive`: the app switcher or a call
  // banner leaves it in view.
  late final AppLifecycleListener _lifecycle;

  int _bpm = 96;
  _Meter _meter = _Meter.fourFour;
  bool _running = false;
  Timer? _timer;

  Duration _anchor = Duration.zero;
  Duration _lastBeatAt = Duration.zero;
  int _n = 0;
  int _beatInBar = -1;
  int _beats = 0;

  Duration get _interval => Duration(microseconds: (60e6 / _bpm).round());

  void _start() {
    FlutterHaptics.perform(AppHaptics.press);
    _beats = 0;
    _n = 0;
    _anchor = _clock.elapsed + const Duration(milliseconds: 250);
    setState(() => _running = true);
    _ticker.start();
    _schedule();
  }

  void _stop() {
    _timer?.cancel();
    _ticker.stop();
    setState(() {
      _running = false;
      _beatInBar = -1;
    });
  }

  /// Every beat is scheduled from the anchor, never from the previous
  /// timer: late timers do not accumulate into drift.
  void _schedule() {
    // Beats already in the past are skipped, never fired back-to-back: a
    // burst of catch-up beats is one fused buzz and breaks the downbeat.
    final now = _clock.elapsed;
    while (_anchor + _interval * _n < now) {
      _n++;
    }
    final wait = _anchor + _interval * _n - now;
    _timer = Timer(wait, _fire);
  }

  void _fire() {
    if (!_running || !mounted) return;
    final beat = _beats % _meter.beats;
    if (_meter.accents.contains(beat)) {
      _accent.play();
    } else if (_meter.isSecondary(beat)) {
      _secondary.play();
    } else {
      _beat.play();
    }
    _lastBeatAt = _clock.elapsed;
    setState(() => _beatInBar = beat);
    _beats++;
    _n++;
    _schedule();
  }

  void _setBpm(int bpm, {required bool fromSlider}) {
    final clamped = bpm.clamp(MetronomeDemo.minBpm, MetronomeDemo.maxBpm);
    if (clamped == _bpm) {
      if (!fromSlider) FlutterHaptics.perform(AppHaptics.limit);
      return;
    }
    if (fromSlider) {
      final edge =
          clamped == MetronomeDemo.minBpm || clamped == MetronomeDemo.maxBpm;
      if (edge) {
        FlutterHaptics.perform(AppHaptics.limit);
      } else if (clamped ~/ 10 != _bpm ~/ 10 && _sliderPacer.ready()) {
        FlutterHaptics.perform(AppHaptics.fineDetent);
      }
    } else {
      FlutterHaptics.perform(AppHaptics.tick);
    }
    setState(() => _bpm = clamped);
    // Re-anchor on the last beat so the new tempo starts from it. Before the
    // first beat there is nothing to anchor on: the pending start stands.
    if (_running && _beats > 0) {
      _timer?.cancel();
      _anchor = _lastBeatAt;
      _n = 1;
      _schedule();
    }
  }

  void _setMeter(_Meter meter) {
    if (meter == _meter) return;
    FlutterHaptics.perform(AppHaptics.tick);
    setState(() {
      _meter = meter;
      _beats = 0;
      _beatInBar = -1;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The tab shell keeps this page alive offstage with its tickers muted,
    // but a Timer is not a ticker. Leaving the tab stops the beat rather
    // than letting it buzz out of sight.
    if (!TickerMode.valuesOf(context).enabled && _running) {
      _timer?.cancel();
      _ticker.stop();
      _running = false;
      _beatInBar = -1;
    }
  }

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () {
        if (_running) _stop();
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _timer?.cancel();
    _ticker.dispose();
    _frame.dispose();
    _accent.dispose();
    _secondary.dispose();
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LabLayout(
      hint:
          'Feel the downbeat. Beat one is strong and crisp, the rest are '
          'lighter — you can keep time without looking or listening.',
      status: Row(
        children: [
          for (final m in _Meter.values) ...[
            ChoiceChip(
              label: Text(m.label),
              selected: m == _meter,
              showCheckmark: false,
              selectedColor: AppColors.lab.withValues(alpha: 0.16),
              side: BorderSide(
                color: m == _meter ? AppColors.lab : AppColors.outline,
              ),
              onSelected: (_) => _setMeter(m),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      stage: LabPanel(
        child: Column(
          children: [
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: _frame,
                builder: (context, _, _) => CustomPaint(
                  size: Size.infinite,
                  painter: _PendulumPainter(
                    angle: _pendulumAngle(),
                    flash: _flash(),
                    accent:
                        _beatInBar >= 0 && _meter.accents.contains(_beatInBar),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _meter.beats; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 90),
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      width: _meter.accents.contains(i) ? 18 : 12,
                      height: _meter.accents.contains(i) ? 18 : 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _beatInBar
                            ? (_meter.accents.contains(i)
                                  ? AppColors.accent
                                  : AppColors.lab)
                            : AppColors.surfaceHighest,
                        boxShadow: i == _beatInBar
                            ? [
                                BoxShadow(
                                  color:
                                      (_meter.accents.contains(i)
                                              ? AppColors.accent
                                              : AppColors.lab)
                                          .withValues(alpha: 0.6),
                                  blurRadius: 12,
                                ),
                              ]
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      controls: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton.outlined(
                onPressed: () => _setBpm(_bpm - 1, fromSlider: false),
                icon: const Icon(Icons.remove_rounded),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$_bpm',
                      style: AppTypography.mono.copyWith(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const Text('BPM', style: AppTypography.eyebrow),
                  ],
                ),
              ),
              IconButton.outlined(
                onPressed: () => _setBpm(_bpm + 1, fromSlider: false),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.lab,
              thumbColor: AppColors.lab,
              overlayColor: AppColors.lab.withValues(alpha: 0.12),
            ),
            child: Slider(
              min: MetronomeDemo.minBpm.toDouble(),
              max: MetronomeDemo.maxBpm.toDouble(),
              value: _bpm.toDouble(),
              onChanged: (v) => _setBpm(v.round(), fromSlider: true),
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _running
                  ? AppColors.surfaceHighest
                  : AppColors.lab,
              foregroundColor: _running ? AppColors.text : AppColors.onAccent,
            ),
            onPressed: _running ? _stop : _start,
            icon: Icon(
              _running ? Icons.stop_rounded : Icons.play_arrow_rounded,
            ),
            label: Text(
              _running ? 'Stop' : 'Start',
              style: theme.textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }

  /// Swings extreme to extreme between beats, arriving on each one.
  double _pendulumAngle() {
    if (!_running || _beats == 0) return 0;
    final frac =
        ((_clock.elapsed - _lastBeatAt).inMicroseconds /
                _interval.inMicroseconds)
            .clamp(0.0, 1.0);
    final dir = _beats.isEven ? -1.0 : 1.0;
    return dir * math.cos(math.pi * frac) * 0.42;
  }

  double _flash() {
    if (!_running || _beats == 0) return 0;
    final ms = (_clock.elapsed - _lastBeatAt).inMilliseconds;
    return (1 - ms / 180).clamp(0.0, 1.0);
  }
}

class _PendulumPainter extends CustomPainter {
  _PendulumPainter({
    required this.angle,
    required this.flash,
    required this.accent,
  });

  final double angle;
  final double flash;
  final bool accent;

  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(size.width / 2, size.height - 24);
    final length = size.height * 0.72;
    final tip = pivot + Offset(math.sin(angle), -math.cos(angle)) * length;
    final color = accent ? AppColors.accent : AppColors.lab;

    // Arc of travel.
    canvas.drawArc(
      Rect.fromCircle(center: pivot, radius: length),
      -math.pi / 2 - 0.45,
      0.9,
      false,
      Paint()
        ..color = AppColors.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    canvas.drawLine(
      pivot,
      tip,
      Paint()
        ..color = AppColors.textMuted
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    if (flash > 0) {
      canvas.drawCircle(
        tip,
        18 + 18 * flash,
        Paint()
          ..color = color.withValues(alpha: 0.5 * flash)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }
    canvas.drawCircle(tip, 14, Paint()..color = color);
    canvas.drawCircle(pivot, 6, Paint()..color = AppColors.textMuted);
  }

  @override
  bool shouldRepaint(_PendulumPainter oldDelegate) =>
      oldDelegate.angle != angle ||
      oldDelegate.flash != flash ||
      oldDelegate.accent != accent;
}
