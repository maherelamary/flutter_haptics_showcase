import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_patterns.dart';

/// A shutter that sounds like a camera to the hand: two-stage on a tap,
/// a crisp machine-gun tick while held for burst.
class CameraShutterDemo extends StatefulWidget {
  const CameraShutterDemo({super.key});

  @override
  State<CameraShutterDemo> createState() => _CameraShutterDemoState();
}

class _CameraShutterDemoState extends State<CameraShutterDemo>
    with SingleTickerProviderStateMixin {
  /// One frame of a burst: just the bright half of [AppPatterns.shutter],
  /// so 8 frames a second stay distinct instead of smearing into a buzz.
  static const _burstFrame = HapticPattern([
    TransientEvent(intensity: 0.6, sharpness: 1.0),
  ]);
  static const _burstInterval = Duration(milliseconds: 120);
  static const _maxBurst = 30;

  // Starts complete, so the white overlay (driven in reverse) is hidden.
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );
  // Frames are 120 ms apart, well above any device's pacing floor, so the
  // handle lets every one through.
  final HapticHandle _burstTick = FlutterHaptics.register(_burstFrame);

  Timer? _burstTimer;
  int _shots = 0;
  int _burstCount = 0;
  bool _pressed = false;

  void _single() {
    FlutterHaptics.play(AppPatterns.shutter);
    _flash.forward(from: 0);
    setState(() => _shots++);
  }

  void _startBurst() {
    _burstCount = 0;
    setState(() => _pressed = true);
    _frame();
    _burstTimer = Timer.periodic(_burstInterval, (_) => _frame());
  }

  void _frame() {
    if (!mounted || _burstCount >= _maxBurst) {
      _stopBurst();
      return;
    }
    _burstTick.play();
    _flash.forward(from: 0.4);
    setState(() {
      _shots++;
      _burstCount++;
    });
  }

  void _stopBurst() {
    _burstTimer?.cancel();
    _burstTimer = null;
    // Releasing ends the burst silently: the ticks stopping is the feedback.
    if (mounted) setState(() => _pressed = false);
  }

  @override
  void dispose() {
    _burstTimer?.cancel();
    _burstTick.dispose();
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 170,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF1E2A3A), Color(0xFF3A2E22)],
                    ),
                  ),
                ),
                const CustomPaint(painter: _GridPainter()),
                const Center(
                  child: Icon(
                    Icons.filter_center_focus_rounded,
                    size: 36,
                    color: Color(0x88FFFFFF),
                  ),
                ),
                if (_burstTimer != null)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'BURST $_burstCount',
                        style: AppTypography.eyebrow.copyWith(
                          color: Colors.white,
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                  ),
                IgnorePointer(
                  child: FadeTransition(
                    opacity: ReverseAnimation(_flash),
                    child: const ColoredBox(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _shots > 0 ? AppColors.text : AppColors.outline,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$_shots',
                    style: AppTypography.mono.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: _single,
              onLongPressStart: (_) => _startBurst(),
              onLongPressEnd: (_) => _stopBurst(),
              onLongPressCancel: _stopBurst,
              child: AnimatedScale(
                scale: _pressed ? 0.9 : 1,
                duration: const Duration(milliseconds: 120),
                child: Container(
                  width: 72,
                  height: 72,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.text, width: 3),
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _pressed ? AppColors.danger : AppColors.text,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'tap · hold',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}
