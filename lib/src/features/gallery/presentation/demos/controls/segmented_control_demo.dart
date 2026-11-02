import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/controls/route_readout.dart';

/// A period switcher that ticks when — and only when — the period changes.
class SegmentedControlDemo extends StatefulWidget {
  const SegmentedControlDemo({super.key});

  @override
  State<SegmentedControlDemo> createState() => _SegmentedControlDemoState();
}

class _SegmentedControlDemoState extends State<SegmentedControlDemo> {
  static const _periods = ['Day', 'Week', 'Month', 'Year'];
  static const _series = <String, List<double>>{
    'Day': [0.3, 0.5, 0.4, 0.8, 0.6, 0.9, 0.5],
    'Week': [0.6, 0.4, 0.7, 0.5, 0.9, 0.3, 0.6],
    'Month': [0.4, 0.7, 0.9, 0.6, 0.5, 0.8, 1.0],
    'Year': [0.9, 0.8, 0.6, 0.7, 0.4, 0.5, 0.3],
  };

  String _period = 'Week';
  String _call = 'pick a period';
  HapticRoute? _route;
  bool _silent = false;

  Future<void> _select(String period) async {
    if (period == _period) {
      setState(() {
        _call = 'same value — silent';
        _silent = true;
      });
      return;
    }
    setState(() {
      _period = period;
      _call = 'perform(tick)';
      _route = null;
      _silent = false;
    });
    final route = await FlutterHaptics.perform(AppHaptics.tick);
    if (mounted) setState(() => _route = route);
  }

  @override
  Widget build(BuildContext context) {
    final bars = _series[_period]!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            for (final p in _periods)
              ButtonSegment(value: p, label: Text(p)),
          ],
          selected: {_period},
          onSelectionChanged: (selection) => _select(selection.first),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 96,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < bars.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    height: 96 * bars[i],
                    decoration: BoxDecoration(
                      color: i == bars.length - 1
                          ? AppColors.accent
                          : AppColors.accent.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        RouteReadout(call: _call, route: _route, silent: _silent),
      ],
    );
  }
}
