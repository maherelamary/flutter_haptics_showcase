import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';

/// A determinate download: light milestones, one real moment at the end.
class ProgressMilestonesDemo extends StatefulWidget {
  const ProgressMilestonesDemo({super.key});

  @override
  State<ProgressMilestonesDemo> createState() => _ProgressMilestonesDemoState();
}

class _ProgressMilestonesDemoState extends State<ProgressMilestonesDemo>
    with SingleTickerProviderStateMixin {
  static const _marks = [0.25, 0.5, 0.75];

  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )
    ..addListener(_onTick)
    ..addStatusListener(_onStatus);

  bool _milestones = true;
  int _passed = 0;
  bool _done = false;

  void _onTick() {
    final passed = _marks.where((m) => _progress.value >= m).length;
    if (passed <= _passed) return;
    _passed = passed;
    // Light, and only because the user is watching the bar.
    if (_milestones) FlutterHaptics.perform(AppHaptics.fineDetent);
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    FlutterHaptics.perform(AppHaptics.success);
    setState(() => _done = true);
  }

  void _start() {
    FlutterHaptics.perform(AppHaptics.press);
    setState(() {
      _done = false;
      _passed = 0;
    });
    _progress.forward(from: 0);
  }

  void _toggle(bool on) {
    FlutterHaptics.perform(on ? AppHaptics.switchOn : AppHaptics.switchOff);
    setState(() => _milestones = on);
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        final value = _progress.value;
        final running = _progress.isAnimating;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  _done ? Icons.check_circle_rounded : Icons.cloud_download_outlined,
                  size: 20,
                  color: _done ? AppColors.accent : AppColors.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _done
                        ? 'Downloaded'
                        : (running ? 'Downloading…' : 'design-assets.zip'),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  '${(value * 100).round()}%',
                  style: AppTypography.mono.copyWith(
                    color: _done ? AppColors.accent : AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Bar(value: value, marks: _marks, showMarks: _milestones),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: running ? null : _start,
              icon: Icon(_done ? Icons.replay_rounded : Icons.download_rounded),
              label: Text(_done ? 'Download again' : 'Download'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Milestones at 25 · 50 · 75%',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Switch(value: _milestones, onChanged: _toggle),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.marks,
    required this.showMarks,
  });

  final double value;
  final List<double> marks;
  final bool showMarks;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHighest,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              Container(
                height: 10,
                width: width * value,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              if (showMarks)
                for (final mark in marks)
                  Positioned(
                    left: width * mark - 1,
                    top: 0,
                    bottom: 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 2,
                      decoration: BoxDecoration(
                        color: value >= mark
                            ? AppColors.onAccent
                            : AppColors.outlineStrong,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
