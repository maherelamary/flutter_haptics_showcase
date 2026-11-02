import 'package:flutter/material.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/showcase/haptic_definitions.dart';
import 'package:flutter_haptics_showcase/src/core/showcase/showcase_entry.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/code_block.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/pill_tag.dart';

/// The page every Gallery and Lab entry opens into: the live demo, then why
/// it feels the way it does, then the code.
class EntryDetailPage extends StatelessWidget {
  const EntryDetailPage({
    super.key,
    required this.entry,
    this.accent = AppColors.accent,
  });

  final ShowcaseEntry entry;
  final Color accent;

  void _showInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            Text(entry.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(entry.summary, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),
            EntryExplanation(entry: entry, accent: accent),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (entry.immersive) {
      return Scaffold(
        appBar: AppBar(
          title: Text(entry.title),
          actions: [
            IconButton(
              tooltip: 'How it works',
              icon: const Icon(Icons.info_outline_rounded),
              onPressed: () => _showInfo(context),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(top: false, child: Builder(builder: entry.builder)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(entry.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Text(entry.summary, style: Theme.of(context).textTheme.bodyLarge),
          if (entry.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                // Mostly Dart names (`register()`, `HapticArm.pattern`), so
                // their case is kept.
                for (final tag in entry.tags)
                  PillTag(tag, color: accent, uppercase: false),
              ],
            ),
          ],
          const SizedBox(height: 16),
          DemoStage(child: Builder(builder: entry.builder)),
          const SizedBox(height: 28),
          EntryExplanation(entry: entry, accent: accent),
        ],
      ),
    );
  }
}

/// The lit area a live demo sits in.
class DemoStage extends StatelessWidget {
  const DemoStage({super.key, required this.child, this.minHeight = 240});

  final Widget child;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outline),
        gradient: const RadialGradient(
          center: Alignment(0, -0.6),
          radius: 1.2,
          colors: [Color(0xFF17171C), AppColors.surface],
        ),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// Why it feels this way, the haptic map, and the code.
class EntryExplanation extends StatelessWidget {
  const EntryExplanation({super.key, required this.entry, required this.accent});

  final ShowcaseEntry entry;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final references = HapticDefinitions.of(entry);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('WHY IT FEELS THIS WAY', style: AppTypography.eyebrow),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border(left: BorderSide(color: accent, width: 3)),
          ),
          child: Text(
            entry.rationale,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.text),
          ),
        ),
        const SizedBox(height: 28),
        const Text('HAPTIC MAP', style: AppTypography.eyebrow),
        const SizedBox(height: 10),
        HapticMap(moments: entry.moments, accent: accent),
        if (references.isNotEmpty) ...[
          const SizedBox(height: 28),
          const Text('WHAT THESE RESOLVE TO', style: AppTypography.eyebrow),
          const SizedBox(height: 4),
          Text(
            'Read from AppHaptics and AppPatterns at runtime: what each '
            'platform plays, and the pattern behind it.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          HapticDefinitions(references: references, accent: accent),
        ],
        const SizedBox(height: 28),
        const Text('CODE', style: AppTypography.eyebrow),
        const SizedBox(height: 10),
        CodeBlock(entry.code),
      ],
    );
  }
}

/// A two-column table: what the user does, what they feel.
class HapticMap extends StatelessWidget {
  const HapticMap({super.key, required this.moments, this.accent = AppColors.accent});

  final List<HapticMoment> moments;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          for (var i = 0; i < moments.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      moments[i].trigger,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: AppColors.text),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          moments[i].feedback,
                          style: AppTypography.mono.copyWith(
                            color: accent,
                            fontSize: 12,
                          ),
                        ),
                        if (moments[i].note != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            moments[i].note!,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
