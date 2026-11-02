import 'package:flutter/widgets.dart';

/// An [AnimatedSwitcher] that can't throw "Duplicate keys found".
///
/// [AnimatedSwitcher] keeps the outgoing child alive while it animates out.
/// When children are keyed by their value (`ValueKey(_liked)`,
/// `ValueKey(qty)`) and the value comes back before that animation ends —
/// like → unlike → like, 3 → 4 → 3 on a fast stepper — the old and new child
/// briefly share a key inside the switcher's Stack, and Flutter asserts.
///
/// This wraps each incoming child in a [KeyedSubtree] keyed by a generation
/// number that only ever grows. A new generation starts exactly when
/// [AnimatedSwitcher] itself would start a transition (the child's type or
/// key changed), so call sites keep their keys and their behaviour.
class SafeAnimatedSwitcher extends StatefulWidget {
  const SafeAnimatedSwitcher({
    super.key,
    required this.duration,
    this.child,
    this.reverseDuration,
    this.switchInCurve = Curves.linear,
    this.switchOutCurve = Curves.linear,
    this.transitionBuilder = AnimatedSwitcher.defaultTransitionBuilder,
    this.layoutBuilder = AnimatedSwitcher.defaultLayoutBuilder,
  });

  final Widget? child;
  final Duration duration;
  final Duration? reverseDuration;
  final Curve switchInCurve;
  final Curve switchOutCurve;
  final AnimatedSwitcherTransitionBuilder transitionBuilder;
  final AnimatedSwitcherLayoutBuilder layoutBuilder;

  @override
  State<SafeAnimatedSwitcher> createState() => _SafeAnimatedSwitcherState();
}

class _SafeAnimatedSwitcherState extends State<SafeAnimatedSwitcher> {
  int _generation = 0;

  @override
  void didUpdateWidget(SafeAnimatedSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.child;
    final after = widget.child;
    final switched = (before == null) != (after == null) ||
        (before != null && after != null && !Widget.canUpdate(before, after));
    if (switched) _generation++;
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    return AnimatedSwitcher(
      duration: widget.duration,
      reverseDuration: widget.reverseDuration,
      switchInCurve: widget.switchInCurve,
      switchOutCurve: widget.switchOutCurve,
      transitionBuilder: widget.transitionBuilder,
      layoutBuilder: widget.layoutBuilder,
      child: child == null
          ? null
          : KeyedSubtree(key: ValueKey<int>(_generation), child: child),
    );
  }
}
