import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/controls/route_readout.dart';

/// A checklist where one item ticks and a batch speaks once.
class CheckboxListDemo extends StatefulWidget {
  const CheckboxListDemo({super.key});

  @override
  State<CheckboxListDemo> createState() => _CheckboxListDemoState();
}

class _CheckboxListDemoState extends State<CheckboxListDemo> {
  static const _items = ['Oat milk', 'Eggs', 'Sourdough', 'Coffee beans', 'Avocados'];

  final Set<int> _checked = {1};
  String _call = 'tick an item, or select all';
  HapticRoute? _route;

  bool? get _allState {
    if (_checked.length == _items.length) return true;
    if (_checked.isEmpty) return false;
    return null;
  }

  Future<void> _toggle(int index) async {
    setState(() {
      if (!_checked.remove(index)) _checked.add(index);
      _call = 'perform(tick)';
      _route = null;
    });
    final route = await FlutterHaptics.perform(AppHaptics.tick);
    if (mounted) setState(() => _route = route);
  }

  Future<void> _toggleAll() async {
    final selectAll = _allState != true;
    setState(() {
      if (selectAll) {
        _checked.addAll(List.generate(_items.length, (i) => i));
      } else {
        _checked.clear();
      }
      // One summarising haptic for the whole batch — never one per row.
      _call = selectAll ? 'play(doubleClick)' : 'play(soft)';
      _route = null;
    });
    final route = await FlutterHaptics.play(
      selectAll ? HapticPatterns.doubleClick : HapticPatterns.soft,
    );
    if (mounted) setState(() => _route = route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outline),
          ),
          child: Column(
            children: [
              InkWell(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                onTap: _toggleAll,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 2, 14, 2),
                  child: Row(
                    children: [
                      Checkbox(
                        tristate: true,
                        value: _allState,
                        onChanged: (_) => _toggleAll(),
                      ),
                      Expanded(
                        child: Text(
                          'Select all',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        '${_checked.length}/${_items.length}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              for (var i = 0; i < _items.length; i++)
                InkWell(
                  onTap: () => _toggle(i),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 14, 0),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _checked.contains(i),
                          onChanged: (_) => _toggle(i),
                        ),
                        Expanded(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            style: (theme.textTheme.bodyLarge ??
                                    const TextStyle())
                                .copyWith(
                              color: _checked.contains(i)
                                  ? AppColors.textFaint
                                  : AppColors.text,
                              decoration: _checked.contains(i)
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              decorationColor: AppColors.textFaint,
                            ),
                            child: Text(_items[i]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 4),
            ],
          ),
        ),
        const SizedBox(height: 10),
        RouteReadout(call: _call, route: _route),
      ],
    );
  }
}
