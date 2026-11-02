import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/fidelity_simulator.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptics_providers.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/pill_tag.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/tactile_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What this phone can feel, at a glance.
class DeviceCard extends ConsumerWidget {
  const DeviceCard({super.key, this.onTap, this.detailed = false});

  final VoidCallback? onTap;

  /// Adds the per-capability checklist and an explanation.
  final bool detailed;

  static String describe(HapticFidelity fidelity) => switch (fidelity) {
        HapticFidelity.full =>
          'Intensity, sharpness and curves all survive. Core Haptics, or '
              'Android 16 envelope hardware.',
        HapticFidelity.intensity =>
          'Intensity survives, sharpness does not. Patterns read by rhythm '
              'and strength rather than texture.',
        HapticFidelity.rhythm =>
          'A single-speed motor: only timing comes through. Common on budget '
              'handsets, new ones included.',
        HapticFidelity.none =>
          'No haptic hardware here. Every call still succeeds silently.',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final support = ref.watch(hapticSupportProvider);
    final settings = ref.watch(hapticsSettingsProvider);
    final theme = Theme.of(context);

    return TactileCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: support.when(
        loading: () => const SizedBox(
          height: 64,
          child: Center(child: LinearProgressIndicator()),
        ),
        error: (_, _) => const Text('Could not read this device.'),
        data: (s) {
          final color = s.isSupported ? AppColors.accent : AppColors.silent;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('THIS DEVICE', style: AppTypography.eyebrow),
                  const Spacer(),
                  if (!settings.enabled)
                    const PillTag(
                      'Haptics off',
                      color: AppColors.danger,
                      icon: Icons.do_not_disturb_on_rounded,
                    )
                  else if (settings.tier != SimulatedTier.native)
                    PillTag(
                      'Simulating ${settings.tier.label}',
                      color: AppColors.warning,
                    ),
                  if (onTap != null) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.textFaint,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    s.fidelity.name,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: color,
                      fontFamily: AppTypography.mono.fontFamily,
                      fontFamilyFallback: AppTypography.mono.fontFamilyFallback,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('fidelity', style: theme.textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 10),
              _Ladder(fidelity: s.fidelity),
              if (detailed) ...[
                const SizedBox(height: 14),
                Text(describe(s.fidelity), style: theme.textTheme.bodyMedium),
                const SizedBox(height: 14),
                _Fact('Anything plays at all', s.isSupported),
                _Fact('Per-event intensity survives', s.supportsIntensity),
                _Fact('Sharpness survives', s.supportsSharpness),
                _Fact('A rumble can sustain', s.supportsContinuous),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Four segments, lit up to this device's tier.
class _Ladder extends StatelessWidget {
  const _Ladder({required this.fidelity});

  final HapticFidelity fidelity;

  @override
  Widget build(BuildContext context) {
    const tiers = [
      HapticFidelity.rhythm,
      HapticFidelity.intensity,
      HapticFidelity.full,
    ];
    return Row(
      children: [
        for (final tier in tiers) ...[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: fidelity.atLeast(tier)
                        ? AppColors.accent
                        : AppColors.surfaceHighest,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tier.name,
                  style: AppTypography.eyebrow.copyWith(
                    fontSize: 9,
                    color: fidelity.atLeast(tier)
                        ? AppColors.text
                        : AppColors.textFaint,
                  ),
                ),
              ],
            ),
          ),
          if (tier != tiers.last) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final bool value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            value ? Icons.check_circle_rounded : Icons.remove_circle_outline,
            size: 18,
            color: value ? AppColors.accent : AppColors.textFaint,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: value ? AppColors.text : AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
