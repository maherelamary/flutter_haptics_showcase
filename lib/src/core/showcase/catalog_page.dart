import 'package:flutter/material.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/showcase/entry_tile.dart';
import 'package:flutter_haptics_showcase/src/core/showcase/showcase_entry.dart';

/// A pillar's landing page: a big title, an intro, and its entries grouped
/// by category in the order [categories] gives.
class CatalogPage extends StatelessWidget {
  const CatalogPage({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.intro,
    required this.entries,
    required this.categories,
    required this.onOpen,
    this.accent = AppColors.accent,
  });

  final String eyebrow;
  final String title;
  final String intro;
  final List<ShowcaseEntry> entries;
  final List<String> categories;
  final ValueChanged<ShowcaseEntry> onOpen;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ordered = <String>{
      ...categories,
      for (final e in entries) e.category,
    }.toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow.toUpperCase(),
                      style: AppTypography.eyebrow.copyWith(color: accent),
                    ),
                    const SizedBox(height: 8),
                    Text(title, style: theme.textTheme.displaySmall),
                    const SizedBox(height: 10),
                    Text(intro, style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.textMuted,
                    )),
                  ],
                ),
              ),
            ),
            if (entries.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('Coming soon')),
              ),
            for (final category in ordered)
              ..._section(
                context,
                category,
                entries.where((e) => e.category == category).toList(),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  List<Widget> _section(
    BuildContext context,
    String category,
    List<ShowcaseEntry> items,
  ) {
    if (items.isEmpty) return const [];
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              Text(category.toUpperCase(), style: AppTypography.eyebrow),
              const SizedBox(width: 8),
              Text(
                '${items.length}',
                style: AppTypography.eyebrow.copyWith(color: AppColors.textFaint),
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) => EntryTile(
            entry: items[i],
            accent: accent,
            onTap: () => onOpen(items[i]),
          ),
        ),
      ),
    ];
  }
}
