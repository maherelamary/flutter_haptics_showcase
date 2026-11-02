import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/haptic_echo.dart';

/// A check that springs in with two rings bursting behind it — the visual
/// half of a success haptic. Play the haptic on the frame this appears.
class SuccessBurst extends StatefulWidget {
  const SuccessBurst({
    super.key,
    this.color = AppColors.accent,
    this.size = 112,
    this.icon = Icons.check_rounded,
  });

  final Color color;
  final double size;
  final IconData icon;

  @override
  State<SuccessBurst> createState() => _SuccessBurstState();
}

class _SuccessBurstState extends State<SuccessBurst> {
  int _burst = 0;
  Timer? _second;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _burst = 1);
      _second = Timer(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _burst = 2);
      });
    });
  }

  @override
  void dispose() {
    _second?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HapticEcho(
      trigger: _burst,
      color: widget.color,
      spread: 2.2,
      duration: const Duration(milliseconds: 700),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 650),
        curve: Curves.elasticOut,
        builder: (context, t, child) => Transform.scale(scale: t, child: child),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.4),
                blurRadius: 40,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            size: widget.size * 0.54,
            color: AppColors.onAccent,
          ),
        ),
      ),
    );
  }
}
