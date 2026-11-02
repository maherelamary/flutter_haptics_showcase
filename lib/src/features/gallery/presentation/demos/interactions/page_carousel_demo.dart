import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';

/// A paged carousel: each page change is a selection.
class PageCarouselDemo extends StatefulWidget {
  const PageCarouselDemo({super.key});

  @override
  State<PageCarouselDemo> createState() => _PageCarouselDemoState();
}

class _PageCarouselDemoState extends State<PageCarouselDemo> {
  static const _cards = <(String, String, IconData, Color)>[
    ('Focus', 'Deep work · 50 min', Icons.center_focus_strong_rounded, AppColors.accent),
    ('Move', 'Walk · 20 min', Icons.directions_walk_rounded, AppColors.lab),
    ('Read', 'Two chapters', Icons.menu_book_rounded, AppColors.flows),
    ('Create', 'Sketch the dial', Icons.brush_rounded, AppColors.studio),
    ('Rest', 'No screens · 15 min', Icons.self_improvement_rounded, AppColors.system),
  ];

  final PageController _controller = PageController(viewportFraction: 0.85);
  int _page = 0;

  void _onPageChanged(int index) {
    // A page change is a selection; the swipe itself stays quiet.
    FlutterHaptics.perform(AppHaptics.tick);
    setState(() => _page = index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _controller,
            itemCount: _cards.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, i) => AnimatedScale(
              scale: i == _page ? 1 : 0.92,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _Card(index: i, card: _cards[i]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _cards.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: i == _page ? 20 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i == _page ? AppColors.accent : AppColors.outlineStrong,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.index, required this.card});

  final int index;
  final (String, String, IconData, Color) card;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle, icon, color) = card;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.22), AppColors.surfaceRaised],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const Spacer(),
              Text(
                '0${index + 1}',
                style: AppTypography.mono.copyWith(color: color),
              ),
            ],
          ),
          const Spacer(),
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
