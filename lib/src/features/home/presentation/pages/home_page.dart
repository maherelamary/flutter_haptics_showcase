import 'package:flutter/material.dart';
import 'package:flutter_haptics_showcase/src/config/routes/route_paths.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/section_header.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/tactile_card.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/data/gallery_catalog.dart';
import 'package:flutter_haptics_showcase/src/features/home/presentation/widgets/device_card.dart';
import 'package:flutter_haptics_showcase/src/features/home/presentation/widgets/feel_orb.dart';
import 'package:flutter_haptics_showcase/src/features/lab/data/lab_catalog.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pillars = [
      _Pillar(
        title: 'Gallery',
        tagline: 'Everyday controls, wired right',
        count: '${GalleryCatalog.entries.length} components',
        icon: Icons.widgets_rounded,
        color: AppColors.gallery,
        path: RoutePaths.gallery,
      ),
      _Pillar(
        title: 'Lab',
        tagline: 'Textures, physics, dials',
        count: '${LabCatalog.entries.length} experiments',
        icon: Icons.science_rounded,
        color: AppColors.lab,
        path: RoutePaths.lab,
      ),
      const _Pillar(
        title: 'Flows',
        tagline: 'Haptics across a journey',
        count: '3 journeys',
        icon: Icons.route_rounded,
        color: AppColors.flows,
        path: RoutePaths.flows,
      ),
      const _Pillar(
        title: 'Studio',
        tagline: 'Design, feel, export',
        count: 'Dart + AHAP',
        icon: Icons.graphic_eq_rounded,
        color: AppColors.studio,
        path: RoutePaths.studio,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SHOWCASE',
                        style: AppTypography.eyebrow.copyWith(
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Flutter Haptics Tactile',
                        style: theme.textTheme.displaySmall,
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Settings',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceRaised,
                  ),
                  onPressed: () => context.push(RoutePaths.settings),
                  icon: const Icon(Icons.tune_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'The difference between an interface that reacts and one that '
              'responds. Hold your phone; everything here is meant to be felt.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 22),
            const FeelOrb(),
            const SizedBox(height: 14),
            DeviceCard(onTap: () => context.push(RoutePaths.settings)),
            const SizedBox(height: 28),
            const SectionHeader(eyebrow: 'Explore', title: 'Five ways in'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.98,
              children: [for (final p in pillars) _PillarCard(pillar: p)],
            ),
            const SizedBox(height: 12),
            const _SystemCard(),
            const SizedBox(height: 28),
            const SectionHeader(
              eyebrow: 'Principles',
              title: 'Haptics with taste',
            ),
            ..._principles.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PrincipleCard(number: p.$1, title: p.$2, body: p.$3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _principles = [
    (
      '01',
      'Meaning, not decoration',
      'Every haptic answers "what just happened?" — accepted, refused, '
          'crossed a line, hit a limit. If it answers nothing, cut it.',
    ),
    (
      '02',
      'Felt and seen together',
      'Fire the haptic on the same frame as the motion it belongs to. A '
          'buzz that lags its animation reads as a glitch.',
    ),
    (
      '03',
      'Less, but better',
      'Navigation, scrolling and typing in system fields stay quiet. Save '
          'strong, long patterns for moments that happen once.',
    ),
    (
      '04',
      'Design for the cheap phone',
      'Only rhythm survives on a rotary motor. Make every pattern readable '
          'by its timing alone; intensity and sharpness are polish.',
    ),
    (
      '05',
      'One switch, no guards',
      'Respect the user\'s Haptics setting through FlutterHaptics.enabled. '
          'Call sites never check a preference.',
    ),
  ];
}

class _Pillar {
  const _Pillar({
    required this.title,
    required this.tagline,
    required this.count,
    required this.icon,
    required this.color,
    required this.path,
  });

  final String title;
  final String tagline;
  final String count;
  final IconData icon;
  final Color color;
  final String path;
}

class _PillarCard extends StatelessWidget {
  const _PillarCard({required this.pillar});

  final _Pillar pillar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TactileCard(
      onTap: () => context.go(pillar.path),
      padding: const EdgeInsets.all(16),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [pillar.color.withValues(alpha: 0.12), AppColors.surface],
        stops: const [0, 0.6],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: pillar.color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(pillar.icon, color: pillar.color, size: 22),
          ),
          const Spacer(),
          Text(pillar.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(pillar.tagline, style: theme.textTheme.bodySmall),
          const SizedBox(height: 10),
          Text(
            pillar.count.toUpperCase(),
            style: AppTypography.eyebrow.copyWith(color: pillar.color),
          ),
        ],
      ),
    );
  }
}

/// The fifth way in: the platforms' own vocabularies, side by side.
class _SystemCard extends StatelessWidget {
  const _SystemCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TactileCard(
      onTap: () => context.go(RoutePaths.system),
      padding: const EdgeInsets.all(16),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.system.withValues(alpha: 0.12), AppColors.surface],
        stops: const [0, 0.55],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.system.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.devices_rounded,
              color: AppColors.system,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('System', style: theme.textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(
                  "Each OS's own constants, playable one by one",
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '9 IOS · 20 ANDROID',
                  style: AppTypography.eyebrow.copyWith(
                    color: AppColors.system,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
        ],
      ),
    );
  }
}

class _PrincipleCard extends StatelessWidget {
  const _PrincipleCard({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TactileCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: AppTypography.mono.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
