import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptic_registry.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptic_tracer.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptics_providers.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/pattern_waveform.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the haptic recap: every haptic played since [start], laid out as
/// a budget — how many, which route, and how they were spaced.
Future<void> showHapticRecap(
  BuildContext context,
  WidgetRef ref, {
  required DateTime start,
  required String title,
  String? footnote,
}) {
  final traces = ref.read(hapticLogProvider.notifier).since(start);
  final end = DateTime.now();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => HapticRecap(
        traces: traces,
        start: start,
        end: end,
        title: title,
        footnote: footnote,
        controller: controller,
      ),
    ),
  );
}

enum _RecapKind { system, pattern, silent }

/// One felt (or declined) moment. A declined constant immediately followed
/// by its intent's recovery pattern is folded into a single item.
class _RecapItem {
  const _RecapItem({
    required this.at,
    required this.kind,
    required this.tag,
    required this.name,
    this.pattern,
    this.detail,
  });

  final DateTime at;
  final _RecapKind kind;
  final String tag;
  final String name;
  final HapticPattern? pattern;
  final String? detail;

  Color get color => switch (kind) {
    _RecapKind.system => AppColors.system,
    _RecapKind.pattern => AppColors.pattern,
    _RecapKind.silent => AppColors.silent,
  };
}

/// The recap sheet's content.
class HapticRecap extends StatelessWidget {
  const HapticRecap({
    super.key,
    required this.traces,
    required this.start,
    required this.end,
    required this.title,
    this.footnote,
    this.controller,
  });

  final List<HapticTrace> traces;
  final DateTime start;
  final DateTime end;
  final String title;
  final String? footnote;
  final ScrollController? controller;

  static List<_RecapItem> _itemsFrom(List<HapticTrace> traces) {
    final items = <_RecapItem>[];
    for (var i = 0; i < traces.length; i++) {
      final trace = traces[i];
      final next = i + 1 < traces.length ? traces[i + 1] : null;
      final nextPattern = next?.pattern;

      final recovered =
          trace.kind == HapticTraceKind.system &&
          !trace.played &&
          next != null &&
          next.kind == HapticTraceKind.pattern &&
          next.played &&
          next.at.difference(trace.at) < const Duration(milliseconds: 120);

      if (recovered) {
        items.add(
          _RecapItem(
            at: trace.at,
            kind: _RecapKind.pattern,
            tag: 'RECOVERED',
            name:
                '${trace.system?.name ?? 'system'} → '
                '${nextPattern == null ? 'pattern' : HapticRegistry.labelOf(nextPattern)}',
            pattern: nextPattern,
            detail: trace.reason,
          ),
        );
        i++;
        continue;
      }

      final pattern = trace.pattern;
      if (!trace.played) {
        items.add(
          _RecapItem(
            at: trace.at,
            kind: _RecapKind.silent,
            tag: 'SILENT',
            name:
                trace.system?.name ??
                (pattern == null ? 'nothing' : HapticRegistry.labelOf(pattern)),
            detail: trace.reason,
          ),
        );
        continue;
      }

      items.add(switch (trace.kind) {
        HapticTraceKind.system => _RecapItem(
          at: trace.at,
          kind: _RecapKind.system,
          tag: 'SYSTEM',
          name: trace.system?.name ?? 'constant',
        ),
        HapticTraceKind.pattern => _RecapItem(
          at: trace.at,
          kind: _RecapKind.pattern,
          tag: 'PATTERN',
          name: pattern == null ? 'pattern' : HapticRegistry.labelOf(pattern),
          pattern: pattern,
        ),
        HapticTraceKind.replay => _RecapItem(
          at: trace.at,
          kind: _RecapKind.pattern,
          tag: 'HANDLE',
          name: pattern == null ? 'prepared' : HapticRegistry.labelOf(pattern),
          pattern: pattern,
        ),
      });
    }
    return items;
  }

  static String _seconds(Duration d) =>
      (d.inMilliseconds / 1000).toStringAsFixed(1);

  String _verdict(List<_RecapItem> items) {
    final total = end.difference(start);
    if (items.isEmpty) {
      return 'Nothing played. Haptics may be switched off in Settings.';
    }
    var longestGap = items.first.at.difference(start);
    for (var i = 1; i < items.length; i++) {
      final gap = items[i].at.difference(items[i - 1].at);
      if (gap > longestGap) longestGap = gap;
    }
    final tail = end.difference(items.last.at);
    if (tail > longestGap) longestGap = tail;

    final every = total.inMilliseconds / items.length / 1000;
    final tone = every < 1.5
        ? 'Busy — look for moments that could stay quiet.'
        : 'A calm budget: feedback where it means something, silence between.';
    return '${items.length} haptics over ${_seconds(total)}s — about one every '
        '${every.toStringAsFixed(1)}s. Longest quiet stretch '
        '${_seconds(longestGap)}s. $tone';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _itemsFrom(traces);
    final counts = {
      for (final kind in _RecapKind.values)
        kind: items.where((i) => i.kind == kind).length,
    };

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text(
          title.toUpperCase(),
          style: AppTypography.eyebrow.copyWith(color: AppColors.flows),
        ),
        const SizedBox(height: 6),
        Text('Haptic recap', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 18),
        Row(
          children: [
            _Stat(label: 'Total', value: items.length, color: AppColors.text),
            const SizedBox(width: 8),
            _Stat(
              label: 'System',
              value: counts[_RecapKind.system] ?? 0,
              color: AppColors.system,
            ),
            const SizedBox(width: 8),
            _Stat(
              label: 'Pattern',
              value: counts[_RecapKind.pattern] ?? 0,
              color: AppColors.pattern,
            ),
            const SizedBox(width: 8),
            _Stat(
              label: 'Silent',
              value: counts[_RecapKind.silent] ?? 0,
              color: AppColors.silent,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.flows.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: const Border(
              left: BorderSide(color: AppColors.flows, width: 3),
            ),
          ),
          child: Text(
            _verdict(items),
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.text),
          ),
        ),
        if (footnote != null) ...[
          const SizedBox(height: 8),
          Text(footnote!, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 22),
        const Text('TIMELINE', style: AppTypography.eyebrow),
        const SizedBox(height: 10),
        _Timeline(items: items, start: start, end: end),
        const SizedBox(height: 22),
        const Text('EVERY HAPTIC', style: AppTypography.eyebrow),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No haptics recorded in this journey.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          )
        else
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _Row(item: items[i], offset: items[i].at.difference(start)),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: AppTypography.mono.copyWith(
                fontSize: 22,
                height: 1.1,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: AppTypography.eyebrow.copyWith(fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dots along the journey's duration, one per haptic.
class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.items,
    required this.start,
    required this.end,
  });

  final List<_RecapItem> items;
  final DateTime start;
  final DateTime end;

  @override
  Widget build(BuildContext context) {
    final totalMs = math.max(1, end.difference(start).inMilliseconds);
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 27,
                child: Container(height: 1, color: AppColors.outlineStrong),
              ),
              for (final item in items)
                Positioned(
                  left:
                      (item.at.difference(start).inMilliseconds / totalMs)
                              .clamp(0.0, 1.0) *
                          width -
                      5,
                  top: 23,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: item.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.background,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: item.color.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                bottom: 4,
                child: Text(
                  '0s',
                  style: AppTypography.eyebrow.copyWith(fontSize: 8.5),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 4,
                child: Text(
                  '${(totalMs / 1000).toStringAsFixed(0)}s',
                  style: AppTypography.eyebrow.copyWith(fontSize: 8.5),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.offset});

  final _RecapItem item;
  final Duration offset;

  @override
  Widget build(BuildContext context) {
    final pattern = item.pattern;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              '+${(offset.inMilliseconds / 1000).toStringAsFixed(1)}s',
              style: AppTypography.mono.copyWith(
                fontSize: 11,
                color: AppColors.textFaint,
              ),
            ),
          ),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: item.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.tag,
                  style: AppTypography.eyebrow.copyWith(
                    fontSize: 8.5,
                    color: item.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.mono.copyWith(
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.detail != null && item.detail!.isNotEmpty)
                  Text(
                    item.detail!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.mono.copyWith(
                      fontSize: 10,
                      height: 1.3,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          if (pattern != null && pattern.events.isNotEmpty) ...[
            const SizedBox(width: 10),
            SizedBox(
              width: 60,
              child: PatternWaveform(
                pattern: pattern,
                color: item.color,
                height: 20,
                showBaseline: false,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
