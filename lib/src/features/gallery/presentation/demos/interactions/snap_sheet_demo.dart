import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';

/// A bottom sheet whose snap points are detents.
class SnapSheetDemo extends StatelessWidget {
  const SnapSheetDemo({super.key});

  void _open(BuildContext context) {
    // Presenting a sheet is silent: its motion is the feedback.
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SnapSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.vertical_align_top_rounded,
          size: 36,
          color: AppColors.accent,
        ),
        const SizedBox(height: 12),
        Text('Peek · Half · Full', style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
          'Drag the sheet between its snap points. Each one is a notch.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () => _open(context),
          icon: const Icon(Icons.expand_less_rounded),
          label: const Text('Open sheet'),
        ),
      ],
    );
  }
}

class _SnapSheet extends StatefulWidget {
  const _SnapSheet();

  @override
  State<_SnapSheet> createState() => _SnapSheetState();
}

class _SnapSheetState extends State<_SnapSheet> {
  static const _points = [0.35, 0.6, 0.9];
  static const _labels = ['Peek', 'Half', 'Full'];

  int _band = 1;
  double _extent = 0.35;

  /// How many snap points the sheet is at or past.
  int _bandFor(double extent) =>
      _points.where((p) => extent >= p - 0.01).length;

  bool _onExtent(DraggableScrollableNotification n) {
    final band = _bandFor(n.extent);
    if (band != _band) FlutterHaptics.perform(AppHaptics.detent);
    setState(() {
      _band = band;
      _extent = n.extent;
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: _onExtent,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.35,
        minChildSize: 0.2,
        maxChildSize: 0.9,
        snap: true,
        snapSizes: const [0.35, 0.6],
        builder: (context, controller) => DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Snap points', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  Text(
                    '${(_extent * 100).round()}%',
                    style: AppTypography.mono.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < _points.length; i++)
                _SnapRow(
                  label: _labels[i],
                  percent: (_points[i] * 100).round(),
                  passed: _band > i,
                  current: _band - 1 == i,
                ),
              const SizedBox(height: 14),
              Text(
                'Crossing a snap point plays AppHaptics.detent — once per '
                'crossing, including the moment the sheet seats after a '
                'fling. Between snap points the drag is silent.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              for (var i = 0; i < 10; i++)
                Container(
                  height: 48,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SnapRow extends StatelessWidget {
  const _SnapRow({
    required this.label,
    required this.percent,
    required this.passed,
    required this.current,
  });

  final String label;
  final int percent;
  final bool passed;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final color = current
        ? AppColors.accent
        : (passed ? AppColors.text : AppColors.textFaint);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: current
            ? AppColors.accent.withValues(alpha: 0.1)
            : AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: current
              ? AppColors.accent.withValues(alpha: 0.5)
              : AppColors.outline,
        ),
      ),
      child: Row(
        children: [
          Icon(
            passed ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: color),
          ),
          const Spacer(),
          Text('$percent%', style: AppTypography.mono.copyWith(color: color)),
        ],
      ),
    );
  }
}
