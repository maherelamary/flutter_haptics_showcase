import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/controls/route_readout.dart';

/// Filter chips (many) and choice chips (one): every real change ticks.
class FilterChipsDemo extends StatefulWidget {
  const FilterChipsDemo({super.key});

  @override
  State<FilterChipsDemo> createState() => _FilterChipsDemoState();
}

class _FilterChipsDemoState extends State<FilterChipsDemo> {
  static const _filters = ['Vegan', 'Spicy', 'Open now', 'Delivery', 'Under 15'];
  static const _distances = ['Any', '1 km', '5 km', '10 km'];

  final Set<String> _active = {'Open now'};
  String _distance = '5 km';
  String _call = 'toggle a filter';
  HapticRoute? _route;
  bool _silent = false;

  Future<void> _toggleFilter(String filter, bool on) async {
    setState(() {
      if (on) {
        _active.add(filter);
      } else {
        _active.remove(filter);
      }
      _call = 'perform(tick)';
      _route = null;
      _silent = false;
    });
    final route = await FlutterHaptics.perform(AppHaptics.tick);
    if (mounted) setState(() => _route = route);
  }

  Future<void> _choose(String distance) async {
    if (distance == _distance) {
      // Re-selecting the current choice changes nothing, so it says nothing.
      setState(() {
        _call = 'already selected — silent';
        _silent = true;
      });
      return;
    }
    setState(() {
      _distance = distance;
      _call = 'perform(tick)';
      _route = null;
      _silent = false;
    });
    final route = await FlutterHaptics.perform(AppHaptics.tick);
    if (mounted) setState(() => _route = route);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('FILTERS · ANY NUMBER', style: AppTypography.eyebrow),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in _filters)
              FilterChip(
                label: Text(f),
                selected: _active.contains(f),
                onSelected: (on) => _toggleFilter(f, on),
              ),
          ],
        ),
        const SizedBox(height: 20),
        const Text('DISTANCE · EXACTLY ONE', style: AppTypography.eyebrow),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in _distances)
              ChoiceChip(
                label: Text(d),
                selected: d == _distance,
                selectedColor: AppColors.accent,
                labelStyle: TextStyle(
                  color: d == _distance ? AppColors.onAccent : AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
                showCheckmark: false,
                onSelected: (_) => _choose(d),
              ),
          ],
        ),
        const SizedBox(height: 14),
        RouteReadout(call: _call, route: _route, silent: _silent),
      ],
    );
  }
}
