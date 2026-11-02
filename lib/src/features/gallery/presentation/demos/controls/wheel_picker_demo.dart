import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';

/// A time picker whose wheels click past each value, like a real dial.
class WheelPickerDemo extends StatefulWidget {
  const WheelPickerDemo({super.key});

  @override
  State<WheelPickerDemo> createState() => _WheelPickerDemoState();
}

class _WheelPickerDemoState extends State<WheelPickerDemo> {
  static const _itemExtent = 40.0;
  static const _height = 180.0;

  // A fling passes dozens of values a second: a registered handle skips the
  // per-call serialisation, and paces itself to the device's own floor so
  // the ticks stay distinct instead of fusing into a buzz.
  final HapticHandle _tick = FlutterHaptics.register(HapticPatterns.selection);

  late final FixedExtentScrollController _hours =
      FixedExtentScrollController(initialItem: 6);
  late final FixedExtentScrollController _minutes =
      FixedExtentScrollController(initialItem: 30);
  late final FixedExtentScrollController _period =
      FixedExtentScrollController();

  int _hour = 7;
  int _minute = 30;
  int _periodIndex = 0;
  int _played = 0;
  int _paced = 0;

  Future<void> _tickOnce() async {
    final route = await _tick.play();
    // `none` also means haptics are switched off; that is not pacing.
    if (!mounted || !FlutterHaptics.enabled) return;
    setState(() => route == HapticRoute.none ? _paced++ : _played++);
  }

  @override
  void dispose() {
    _tick.dispose();
    _hours.dispose();
    _minutes.dispose();
    _period.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final time = '${_hour.toString().padLeft(2, '0')}:'
        '${_minute.toString().padLeft(2, '0')} '
        '${_periodIndex == 0 ? 'AM' : 'PM'}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text(
            time,
            style: AppTypography.mono.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: _height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: _itemExtent,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _Wheel(
                      controller: _hours,
                      looping: true,
                      count: 12,
                      selected: _hour - 1,
                      label: (i) => '${i + 1}'.padLeft(2, '0'),
                      onChanged: (i) {
                        _tickOnce();
                        setState(() => _hour = i % 12 + 1);
                      },
                    ),
                  ),
                  Text(
                    ':',
                    style: AppTypography.mono.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: _Wheel(
                      controller: _minutes,
                      looping: true,
                      count: 60,
                      selected: _minute,
                      label: (i) => '$i'.padLeft(2, '0'),
                      onChanged: (i) {
                        _tickOnce();
                        setState(() => _minute = i % 60);
                      },
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: _Wheel(
                      controller: _period,
                      looping: false,
                      count: 2,
                      selected: _periodIndex,
                      label: (i) => i == 0 ? 'AM' : 'PM',
                      onChanged: (i) {
                        _tickOnce();
                        setState(() => _periodIndex = i);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'handle ticks: $_played · paced out: $_paced · '
          'floor ${_tick.minInterval.inMilliseconds} ms',
          textAlign: TextAlign.center,
          style: AppTypography.mono.copyWith(
            fontSize: 10.5,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.controller,
    required this.looping,
    required this.count,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final FixedExtentScrollController controller;
  final bool looping;
  final int count;
  final int selected;
  final String Function(int index) label;
  final ValueChanged<int> onChanged;

  Widget _item(int index) {
    final i = index % count;
    final isSelected = i == selected;
    return Center(
      child: Text(
        label(i),
        style: AppTypography.mono.copyWith(
          fontSize: 22,
          height: 1,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          color: isSelected ? AppColors.text : AppColors.textFaint,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: _WheelPickerDemoState._itemExtent,
      diameterRatio: 1.4,
      perspective: 0.004,
      physics: const WheelPhysics(),
      onSelectedItemChanged: onChanged,
      childDelegate: looping
          ? ListWheelChildLoopingListDelegate(
              children: [for (var i = 0; i < count; i++) _item(i)],
            )
          : ListWheelChildBuilderDelegate(
              childCount: count,
              builder: (context, index) => _item(index),
            ),
    );
  }
}

/// Wheel physics that settle like a native picker.
///
/// Stock [FixedExtentScrollPhysics] inherits the platform's fling: on iOS
/// that means slow deceleration *and* momentum that stacks across flicks, so
/// a few quick swipes on a looping wheel spin for seconds — and a ticking
/// haptic per item turns that into a long buzz. Capping the fling, refusing
/// to carry momentum and decelerating fast keeps a flick to about a second.
class WheelPhysics extends FixedExtentScrollPhysics {
  const WheelPhysics({
    super.parent = const BouncingScrollPhysics(
      decelerationRate: ScrollDecelerationRate.fast,
    ),
  });

  @override
  WheelPhysics applyTo(ScrollPhysics? ancestor) =>
      WheelPhysics(parent: buildParent(ancestor));

  /// Roughly two dozen items a second at the start of a hard flick.
  @override
  double get maxFlingVelocity => 2400;

  /// Each flick starts from rest instead of adding to the last one.
  @override
  double carriedMomentum(double existingVelocity) => 0;
}
