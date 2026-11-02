import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_patterns.dart';

/// A button that commits only after being held, for actions that must never
/// happen by accident — a payment.
///
/// The haptic tracks the hold: `chargeUp` rises for exactly as long as the
/// ring fills, a bolt-home `lock` marks the commit, and letting go early
/// stops the rumble mid-swell and lands a soft tap, so the user feels that
/// nothing happened.
class HoldToPayButton extends StatefulWidget {
  const HoldToPayButton({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.enabled = true,
    this.duration = const Duration(milliseconds: 800),
    this.accent = AppColors.accent,
  });

  final String label;
  final VoidCallback onConfirmed;
  final bool enabled;

  /// How long to hold. Matches `HapticPatterns.chargeUp` (800 ms).
  final Duration duration;
  final Color accent;

  @override
  State<HoldToPayButton> createState() => _HoldToPayButtonState();
}

class _HoldToPayButtonState extends State<HoldToPayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: widget.duration,
    reverseDuration: const Duration(milliseconds: 260),
  )..addStatusListener(_onStatus);

  bool _holding = false;
  bool _done = false;
  Offset? _downAt;

  /// The finger doing the holding. A second finger neither restarts the
  /// hold nor ends it.
  int? _pointer;

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _holding) {
      _holding = false;
      _confirm();
    }
  }

  void _confirm() {
    if (_done) return;
    final interrupted = _holding;
    // A screen-reader confirm mid-hold: without this the ring would still
    // complete and confirm the payment a second time.
    _holding = false;
    setState(() => _done = true);
    if (interrupted) {
      // chargeUp is still rising: cut it so the lock lands on its own.
      FlutterHaptics.stop().then((_) => FlutterHaptics.play(AppPatterns.lock));
    } else {
      FlutterHaptics.play(AppPatterns.lock);
    }
    widget.onConfirmed();
  }

  void _down(PointerDownEvent event) {
    if (!widget.enabled || _done || _pointer != null) return;
    _pointer = event.pointer;
    _downAt = event.position;
    _holding = true;
    _hold.forward(from: 0);
    FlutterHaptics.play(HapticPatterns.chargeUp);
  }

  /// A Listener isn't part of the gesture arena, so a scroll that starts on
  /// the button would otherwise keep the hold — and confirm the payment.
  /// Moving past touch slop is a scroll, not a hold: abort.
  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    final start = _downAt;
    if (!_holding || start == null) return;
    final slop = MediaQuery.maybeGestureSettingsOf(context)?.touchSlop ?? 18;
    if ((event.position - start).distance > slop) _up();
  }

  Future<void> _up() async {
    _downAt = null;
    if (!_holding) return;
    _holding = false;
    _hold.reverse();
    await FlutterHaptics.stop();
    // Pressed again while stopping: the soft tap would land on the new
    // hold's rumble.
    if (_holding || !mounted) return;
    await FlutterHaptics.play(HapticPatterns.soft);
  }

  void _release(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    _up();
  }

  @override
  void dispose() {
    if (_holding) FlutterHaptics.stop(); // never leave chargeUp running
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !_done;
    // A screen reader's double-tap is a press and an immediate release,
    // which aborts the hold, so it gets an action of its own.
    return Semantics(
      button: true,
      enabled: enabled,
      label: _done ? 'Confirmed' : widget.label,
      onTap: enabled ? _confirm : null,
      excludeSemantics: true,
      child: Listener(
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _release,
        onPointerCancel: _release,
        child: AnimatedBuilder(
          animation: _hold,
          builder: (context, _) {
            final t = _hold.value;
            return AnimatedScale(
              scale: _holding ? 0.98 : 1,
              duration: const Duration(milliseconds: 160),
              child: Container(
                height: 60,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: enabled || _done
                      ? AppColors.surfaceRaised
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _done || t > 0
                        ? widget.accent
                        : enabled
                        ? AppColors.outlineStrong
                        : AppColors.outline,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _done ? 1 : t,
                        child: ColoredBox(
                          color: widget.accent.withValues(
                            alpha: _done ? 1 : 0.22,
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: _done
                                  ? const Icon(
                                      Icons.lock_rounded,
                                      color: AppColors.onAccent,
                                    )
                                  : CircularProgressIndicator(
                                      value: t,
                                      strokeWidth: 3,
                                      color: widget.accent,
                                      backgroundColor: AppColors.surfaceHighest,
                                    ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                _done
                                    ? 'Confirmed'
                                    : _holding
                                    ? 'Keep holding…'
                                    : widget.label,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: _done
                                          ? AppColors.onAccent
                                          : enabled
                                          ? AppColors.text
                                          : AppColors.textFaint,
                                    ),
                              ),
                            ),
                            if (!_done)
                              Icon(
                                Icons.fingerprint_rounded,
                                color: enabled
                                    ? widget.accent
                                    : AppColors.textFaint,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
