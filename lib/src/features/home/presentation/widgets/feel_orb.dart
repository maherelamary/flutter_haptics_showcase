import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_patterns.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/haptic_echo.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/pattern_waveform.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/safe_animated_switcher.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/tactile_card.dart';

/// The first thing on the home screen: one orb, a different feel per tap.
class FeelOrb extends StatefulWidget {
  const FeelOrb({super.key});

  @override
  State<FeelOrb> createState() => _FeelOrbState();
}

class _FeelOrbState extends State<FeelOrb> {
  static const _tour = <(String, String, HapticPattern)>[
    ('heartbeat', 'Two beats, the second stronger.', HapticPatterns.heartbeat),
    ('success', 'Three taps climbing in strength and crispness.', HapticPatterns.success),
    ('impactDecay', 'A sharp hit with a fading tail.', HapticPatterns.impactDecay),
    ('coin', 'Two bright pings, the second higher.', AppPatterns.coin),
    ('chargeUp', 'A rumble building to a peak.', HapticPatterns.chargeUp),
    ('shutter', 'Mirror up, mirror down.', AppPatterns.shutter),
    ('explosion', 'A blast that fades away.', HapticPatterns.explosion),
    ('celebrate', 'The payment-complete moment.', AppPatterns.celebrate),
  ];

  int _index = -1;

  void _feel() {
    final next = (_index + 1) % _tour.length;
    FlutterHaptics.play(_tour[next].$3);
    setState(() => _index = next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = _index < 0 ? null : _tour[_index];

    return TactileCard(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      gradient: const RadialGradient(
        center: Alignment(0, -0.45),
        radius: 1.1,
        colors: [Color(0xFF1C2108), AppColors.surface],
      ),
      child: Column(
        children: [
          HapticEcho(
            trigger: _index,
            spread: 1.9,
            child: PressableScale(
              onTap: _feel,
              pressedScale: 0.92,
              child: Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    center: Alignment(-0.3, -0.35),
                    colors: [Color(0xFFF1FF9E), AppColors.accent, Color(0xFF7E9A12)],
                    stops: [0, 0.45, 1],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.35),
                      blurRadius: 48,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.touch_app_rounded,
                  size: 40,
                  color: AppColors.onAccent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          SafeAnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Column(
              key: ValueKey(_index),
              children: [
                Text(
                  current == null ? 'Tap the orb' : current.$1,
                  style: current == null
                      ? theme.textTheme.titleMedium
                      : AppTypography.mono.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  current == null
                      ? 'Each tap plays a different pattern.'
                      : current.$2,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PatternWaveform(
            pattern: current?.$3 ?? HapticPattern.empty,
            height: 36,
            minDuration: const Duration(milliseconds: 700),
          ),
        ],
      ),
    );
  }
}
