import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Drives a [Shaker]. Call [shake] when input is rejected.
class ShakeController extends ChangeNotifier {
  void shake() => notifyListeners();
}

/// Shakes its child horizontally — the visual half of a "no".
///
/// Pair it with `AppHaptics.failure` so the error is felt and seen at the
/// same instant: motion and haptics that disagree read as a glitch.
class Shaker extends StatefulWidget {
  const Shaker({
    super.key,
    required this.controller,
    required this.child,
    this.distance = 10,
  });

  final ShakeController controller;
  final Widget child;
  final double distance;

  @override
  State<Shaker> createState() => _ShakerState();
}

class _ShakerState extends State<Shaker> with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onShake);
  }

  @override
  void didUpdateWidget(Shaker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onShake);
      widget.controller.addListener(_onShake);
    }
  }

  void _onShake() => _animation.forward(from: 0);

  @override
  void dispose() {
    widget.controller.removeListener(_onShake);
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (context, child) {
        final t = _animation.value;
        // Three decaying swings.
        final dx = math.sin(t * math.pi * 6) * widget.distance * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}
