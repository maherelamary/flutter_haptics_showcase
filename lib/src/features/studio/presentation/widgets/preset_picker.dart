import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/pattern_waveform.dart';

/// A horizontal strip of library patterns to start from.
class PresetStrip extends StatelessWidget {
  const PresetStrip({
    super.key,
    required this.presets,
    required this.onPick,
    this.onBrowse,
  });

  final Map<String, HapticPattern> presets;
  final void Function(String name, HapticPattern pattern) onPick;
  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    final entries = presets.entries.toList();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: entries.length + (onBrowse == null ? 0 : 1),
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (onBrowse != null && i == 0) {
            return ActionChip(
              avatar: const Icon(
                Icons.grid_view_rounded,
                size: 16,
                color: AppColors.studio,
              ),
              label: const Text('All'),
              onPressed: onBrowse,
            );
          }
          final entry = entries[onBrowse == null ? i : i - 1];
          return ActionChip(
            label: Text(
              entry.key,
              style: AppTypography.mono.copyWith(fontSize: 12, height: 1.2),
            ),
            onPressed: () => onPick(entry.key, entry.value),
          );
        },
      ),
    );
  }
}

/// Every library pattern as a card with its waveform. Returns the pick.
Future<MapEntry<String, HapticPattern>?> showPresetSheet(
  BuildContext context,
  Map<String, HapticPattern> presets,
) {
  return showModalBottomSheet<MapEntry<String, HapticPattern>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, controller) {
        final entries = presets.entries.toList();
        return CustomScrollView(
          controller: controller,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRESETS',
                      style: AppTypography.eyebrow.copyWith(
                        color: AppColors.studio,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Start from a pattern',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'The package library and Flutter Haptics Tactile\'s own. Loading one '
                      'approximates it with Studio events.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.1,
                ),
                itemCount: entries.length,
                itemBuilder: (context, i) => _PresetCard(
                  name: entries[i].key,
                  pattern: entries[i].value,
                  onTap: () => Navigator.of(context).pop(entries[i]),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.name,
    required this.pattern,
    required this.onTap,
  });

  final String name;
  final HapticPattern pattern;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceRaised,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.mono.copyWith(
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              PatternWaveform(
                pattern: pattern,
                color: AppColors.studio,
                height: 24,
                showBaseline: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
