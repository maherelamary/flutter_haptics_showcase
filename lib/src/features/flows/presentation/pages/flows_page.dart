import 'package:flutter/material.dart';
import 'package:flutter_haptics_showcase/src/config/routes/route_paths.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/tactile_card.dart';
import 'package:go_router/go_router.dart';

class _Journey {
  const _Journey({
    required this.title,
    required this.summary,
    required this.duration,
    required this.icon,
    required this.satellites,
    required this.color,
    required this.path,
    required this.moments,
  });

  final String title;
  final String summary;
  final String duration;
  final IconData icon;

  /// Smaller icons orbiting the main one in the header.
  final List<IconData> satellites;
  final Color color;
  final String path;

  /// (what you do, what you feel)
  final List<(String, String)> moments;
}

/// The Flows pillar: haptics as a rhythm across a whole journey, not a
/// property of single widgets.
class FlowsPage extends StatelessWidget {
  const FlowsPage({super.key});

  static const _journeys = [
    _Journey(
      title: 'Checkout & pay',
      summary:
          'Cart, delivery, a promo code that can be refused, a '
          'hold-to-pay — and the one celebration a purchase deserves.',
      duration: '≈ 1 min',
      icon: Icons.shopping_bag_rounded,
      satellites: [
        Icons.add_circle_outline_rounded,
        Icons.local_offer_outlined,
        Icons.fingerprint_rounded,
      ],
      color: AppColors.flows,
      path: RoutePaths.checkout,
      moments: [
        ('Change a quantity', 'tick · bump at the limit'),
        ('Swipe an item away', 'armed / disarmed · press'),
        ('Apply a bad code', 'failure + shake'),
        ('Hold to pay', 'chargeUp → lock'),
        ('Processing', 'silence'),
        ('Paid', 'celebrate'),
      ],
    ),
    _Journey(
      title: 'Onboarding',
      summary:
          'Intro pages, a one-time code, permissions — and choosing '
          'whether the app should buzz at all.',
      duration: '≈ 1 min',
      icon: Icons.waving_hand_rounded,
      satellites: [
        Icons.dialpad_rounded,
        Icons.toggle_on_rounded,
        Icons.vibration_rounded,
      ],
      color: AppColors.accent,
      path: RoutePaths.onboarding,
      moments: [
        ('Swipe a page', 'tick'),
        ('Type the code', 'key per digit'),
        ('Wrong code', 'failure + shake'),
        ('Flip a permission', 'switchOn / switchOff'),
        ('All set', 'success'),
      ],
    ),
    _Journey(
      title: 'Messaging',
      summary:
          'Send, react, reply — and when an incoming message should '
          'stay silent.',
      duration: '≈ 2 min',
      icon: Icons.chat_bubble_rounded,
      satellites: [
        Icons.send_rounded,
        Icons.favorite_rounded,
        Icons.reply_rounded,
      ],
      color: AppColors.studio,
      path: RoutePaths.chat,
      moments: [
        ('Send', 'whoosh'),
        ('Long-press a message', 'longPress'),
        ('Slide across reactions', 'tick (paced)'),
        ('Let go on one', 'pop'),
        ('Swipe to reply', 'armed / disarmed'),
        ('Reply while you watch', 'silence'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
          children: [
            Text(
              'FLOWS',
              style: AppTypography.eyebrow.copyWith(color: AppColors.flows),
            ),
            const SizedBox(height: 8),
            Text('Journeys', style: theme.textTheme.displaySmall),
            const SizedBox(height: 10),
            Text(
              'A single widget can feel right and a whole journey still feel '
              'noisy. Haptics have a rhythm across a flow — and a budget. '
              'Each journey ends with a recap of every haptic it spent.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 22),
            for (final journey in _journeys) ...[
              _JourneyCard(journey: journey),
              const SizedBox(height: 14),
            ],
            const SizedBox(height: 8),
            const _BudgetNote(),
          ],
        ),
      ),
    );
  }
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.journey});

  final _Journey journey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TactileCard(
      onTap: () => context.push(journey.path),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _JourneyHeader(journey: journey),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        journey.title,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    Text(
                      journey.duration.toUpperCase(),
                      style: AppTypography.eyebrow.copyWith(
                        color: journey.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(journey.summary, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 14),
                for (final (trigger, feel) in journey.moments)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(top: 7, right: 10),
                          decoration: BoxDecoration(
                            color: feel == 'silence'
                                ? AppColors.silent
                                : journey.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            trigger,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          feel,
                          style: AppTypography.mono.copyWith(
                            fontSize: 11,
                            height: 1.4,
                            color: feel == 'silence'
                                ? AppColors.textFaint
                                : journey.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      'Start journey',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: journey.color,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: journey.color,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// An abstract "illustration": the journey's icon with its satellites,
/// over concentric rings in the journey's colour.
class _JourneyHeader extends StatelessWidget {
  const _JourneyHeader({required this.journey});

  final _Journey journey;

  @override
  Widget build(BuildContext context) {
    final color = journey.color;
    const positions = [
      Alignment(-0.62, -0.35),
      Alignment(0.6, -0.5),
      Alignment(0.38, 0.62),
    ];
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
      child: Container(
        height: 132,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.2),
            radius: 1.3,
            colors: [color.withValues(alpha: 0.2), AppColors.surface],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (final size in const [180.0, 124.0])
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.14)),
                ),
              ),
            for (var i = 0; i < journey.satellites.length; i++)
              Align(
                alignment: positions[i % positions.length],
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withValues(alpha: 0.35)),
                  ),
                  child: Icon(journey.satellites[i], size: 17, color: color),
                ),
              ),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 28,
                  ),
                ],
              ),
              child: Icon(journey.icon, color: AppColors.onAccent, size: 30),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetNote extends StatelessWidget {
  const _BudgetNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.flows.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: AppColors.flows, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THE HAPTIC BUDGET',
            style: AppTypography.eyebrow.copyWith(color: AppColors.flows),
          ),
          const SizedBox(height: 8),
          Text(
            'Spend haptics where the user commits, crosses a line or hits a '
            'limit. Spend nothing while they wait, browse or watch. One long '
            'pattern per journey, at the moment that matters most.',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.text),
          ),
        ],
      ),
    );
  }
}
