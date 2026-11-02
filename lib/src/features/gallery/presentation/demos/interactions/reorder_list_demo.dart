import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';

/// Long-press a row to lift it; feel it leave and land.
class ReorderListDemo extends StatefulWidget {
  const ReorderListDemo({super.key});

  @override
  State<ReorderListDemo> createState() => _ReorderListDemoState();
}

class _ReorderListDemoState extends State<ReorderListDemo> {
  final List<String> _items = [
    'Morning run',
    'Review PR #482',
    'Tune toggle haptics',
    'Lunch with Sara',
    'Ship 1.4',
  ];

  // onReorderItem hands over the index after removal: no off-by-one fix.
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
  }

  Widget _proxy(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = Curves.easeOut.transform(animation.value);
        return Transform.scale(
          scale: 1 + 0.04 * t,
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TaskRow(title: _items[index], lift: t),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 300,
          child: ReorderableListView(
            padding: EdgeInsets.zero,
            onReorderItem: _onReorder,
            // Lift on pick-up, settle on drop. Nothing in between: the
            // moving row is feedback enough.
            onReorderStart: (_) => FlutterHaptics.perform(AppHaptics.lift),
            onReorderEnd: (_) => FlutterHaptics.perform(AppHaptics.drop),
            proxyDecorator: _proxy,
            children: [
              for (final item in _items)
                Padding(
                  key: ValueKey(item),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _TaskRow(title: item),
                ),
            ],
          ),
        ),
        Text(
          'Long-press a row to lift it.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.title, this.lift = 0});

  final String title;

  /// 0 at rest, 1 fully lifted.
  final double lift;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Color.lerp(AppColors.surfaceRaised, AppColors.surfaceHighest, lift),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Color.lerp(
            AppColors.outline,
            AppColors.accent.withValues(alpha: 0.6),
            lift,
          )!,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.22 * lift),
            blurRadius: 24 * lift,
            offset: Offset(0, 8 * lift),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.outlineStrong, width: 1.5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.text),
            ),
          ),
          Icon(
            Icons.drag_indicator_rounded,
            size: 20,
            color: lift > 0 ? AppColors.accent : AppColors.textFaint,
          ),
        ],
      ),
    );
  }
}
