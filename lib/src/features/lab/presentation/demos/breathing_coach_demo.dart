import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/fidelity_simulator.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptics_providers.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/pill_tag.dart';
import 'package:flutter_haptics_showcase/src/features/lab/domain/lab_patterns.dart';
import 'package:flutter_haptics_showcase/src/features/lab/presentation/widgets/lab_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _Phase {
  inhale('Breathe in'),
  holdIn('Hold'),
  exhale('Breathe out'),
  holdOut('Hold');

  const _Phase(this.label);

  final String label;
}

/// Box breathing you can follow with your eyes closed: a slow swell on the
/// way in, a slow ebb on the way out, stillness while you hold.
class BreathingCoachDemo extends ConsumerStatefulWidget {
  const BreathingCoachDemo({super.key});

  static const phase = Duration(seconds: 4);

  /// A four-second swell. Deliberately faint: guidance, not an alarm.
  static const inhale = HapticPattern([
    ContinuousEvent.curved(
      intensity: LinearParam(from: 0.05, to: 0.35),
      sharpness: ConstantParam(0.12),
      duration: phase,
    ),
  ]);

  /// The same swell, reversed.
  static const exhale = HapticPattern([
    ContinuousEvent.curved(
      intensity: LinearParam(from: 0.35, to: 0.05),
      sharpness: ConstantParam(0.12),
      duration: phase,
    ),
  ]);

  @override
  ConsumerState<BreathingCoachDemo> createState() => _BreathingCoachDemoState();
}

class _BreathingCoachDemoState extends ConsumerState<BreathingCoachDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cycle = AnimationController(
    vsync: this,
    duration: BreathingCoachDemo.phase * 4,
  )..addListener(_onFrame);

  _Phase? _phase;
  int _cycles = 0;
  Timer? _taps;
  late final AppLifecycleListener _lifecycle;

  bool get _running => _cycle.isAnimating;

  /// On a rotary motor, four seconds of "faint" rumble is four seconds of
  /// full-strength buzz. There, count the seconds with taps instead.
  bool get _useTaps {
    final support = ref.read(hapticSupportProvider).value;
    final tier = ref.read(hapticsSettingsProvider).tier;
    return tier == SimulatedTier.rhythm ||
        (support != null &&
            (!support.supportsContinuous ||
                support.fidelity == HapticFidelity.rhythm));
  }

  void _onFrame() {
    // Resetting the controller on Stop notifies too; that must not start a
    // new inhale after FlutterHaptics.stop().
    if (!_cycle.isAnimating) return;
    final index = (_cycle.value * 4).floor().clamp(0, 3);
    final phase = _Phase.values[index];
    if (phase != _phase) _enter(phase);
    setState(() {});
  }

  void _enter(_Phase phase) {
    _taps?.cancel();
    if (phase == _Phase.inhale && _phase == _Phase.holdOut) _cycles++;
    _phase = phase;
    switch (phase) {
      case _Phase.inhale:
      case _Phase.exhale:
        if (_useTaps) {
          _countWithTaps(rising: phase == _Phase.inhale);
        } else {
          FlutterHaptics.play(
            phase == _Phase.inhale
                ? BreathingCoachDemo.inhale
                : BreathingCoachDemo.exhale,
          );
        }
      case _Phase.holdIn:
      case _Phase.holdOut:
        // Holding is silence. Nothing to feel is the instruction.
        break;
    }
  }

  void _countWithTaps({required bool rising}) {
    var second = 0;
    void tap() {
      final strength = rising ? 0.2 + 0.1 * second : 0.5 - 0.1 * second;
      FlutterHaptics.play(LabPatterns.tap(strength, 0.2));
    }

    tap();
    _taps = Timer.periodic(const Duration(seconds: 1), (t) {
      second++;
      if (second >= 4) {
        t.cancel();
        return;
      }
      tap();
    });
  }

  void _start() {
    FlutterHaptics.perform(AppHaptics.press);
    _phase = null;
    _cycle.repeat();
    setState(() => _cycles = 0);
  }

  void _stop() {
    _cycle.stop();
    _taps?.cancel();
    FlutterHaptics.stop();
    setState(() => _phase = null);
    _cycle.value = 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The tab shell keeps this page alive offstage with its tickers muted,
    // but a muted ticker leaves the counting Timer and the current rumble
    // running. Leaving the tab ends the session.
    if (!TickerMode.valuesOf(context).enabled && _running) _stop();
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
    _taps?.cancel();
    if (_cycle.isAnimating) FlutterHaptics.stop();
    _cycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phase = _phase;
    final t = (_cycle.value * 4) % 1;
    final secondsLeft = phase == null ? 4 : 4 - (t * 4).floor();

    // Orb size: grows on inhale, stays full on hold, shrinks on exhale.
    final eased = Curves.easeInOutSine.transform(t);
    final size = switch (phase) {
      null => 0.35,
      _Phase.inhale => 0.35 + 0.65 * eased,
      _Phase.holdIn => 1.0,
      _Phase.exhale => 1.0 - 0.65 * eased,
      _Phase.holdOut => 0.35,
    };

    final useTaps = _useTaps;

    return LabLayout(
      hint:
          'Box breathing: in for four, hold four, out for four, hold four. '
          'Close your eyes — the swell and ebb guide you.',
      status: Row(
        children: [
          PillTag(
            useTaps ? 'tap per second' : 'continuous swell',
            color: useTaps ? AppColors.warning : AppColors.system,
          ),
          const Spacer(),
          Text(
            _running ? 'CYCLE ${_cycles + 1}' : 'CYCLE —',
            style: AppTypography.eyebrow,
          ),
        ],
      ),
      stage: LabPanel(
        glow: AppColors.system,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxD =
                math.min(constraints.maxWidth, constraints.maxHeight) * 0.78;
            final d = maxD * size;
            return Stack(
              alignment: Alignment.center,
              children: [
                // Guide rings: the smallest and largest the orb gets.
                for (final r in [maxD, maxD * 0.35])
                  Container(
                    width: r,
                    height: r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.outline),
                    ),
                  ),
                Container(
                  width: d,
                  height: d,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.system.withValues(alpha: 0.55),
                        AppColors.system.withValues(alpha: 0.08),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.system.withValues(alpha: 0.25 * size),
                        blurRadius: 60 * size,
                        spreadRadius: 6 * size,
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      phase?.label ?? 'Ready',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phase == null ? 'Press start' : '$secondsLeft',
                      style: AppTypography.mono.copyWith(
                        fontSize: phase == null ? 13 : 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.system,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
      controls: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: _running
              ? AppColors.surfaceHighest
              : AppColors.system,
          foregroundColor: _running ? AppColors.text : AppColors.onAccent,
        ),
        onPressed: _running ? _stop : _start,
        icon: Icon(_running ? Icons.stop_rounded : Icons.play_arrow_rounded),
        label: Text(_running ? 'Stop' : 'Start'),
      ),
    );
  }
}
