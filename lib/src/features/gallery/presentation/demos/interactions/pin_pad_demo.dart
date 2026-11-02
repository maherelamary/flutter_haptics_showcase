import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/safe_animated_switcher.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/shaker.dart';

/// A PIN pad: keys click on touch-down, the verdict lands on its own beat.
class PinPadDemo extends StatefulWidget {
  const PinPadDemo({super.key});

  @override
  State<PinPadDemo> createState() => _PinPadDemoState();
}

enum _PinState { entry, wrong, unlocked }

class _PinPadDemoState extends State<PinPadDemo> {
  static const _secret = '2580';
  static const _length = 4;
  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', '<'],
  ];

  final ShakeController _shake = ShakeController();
  String _pin = '';
  _PinState _state = _PinState.entry;
  Timer? _timer;

  bool get _accepting =>
      _state == _PinState.entry && _pin.length < _length;

  void _digit(String digit) {
    if (!_accepting) return;
    FlutterHaptics.perform(AppHaptics.key);
    setState(() => _pin += digit);
    if (_pin.length == _length) {
      // Let the key click and the last dot land before the verdict, so the
      // two haptics never blur into one.
      _timer = Timer(const Duration(milliseconds: 160), _check);
    }
  }

  void _backspace() {
    if (!_accepting || _pin.isEmpty) return;
    FlutterHaptics.perform(AppHaptics.tap);
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _check() {
    if (!mounted) return;
    if (_pin == _secret) {
      FlutterHaptics.perform(AppHaptics.success);
      setState(() => _state = _PinState.unlocked);
      return;
    }
    FlutterHaptics.perform(AppHaptics.failure);
    _shake.shake();
    setState(() => _state = _PinState.wrong);
    _timer = Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      setState(() {
        _pin = '';
        _state = _PinState.entry;
      });
    });
  }

  void _lock() {
    FlutterHaptics.perform(AppHaptics.tap);
    setState(() {
      _pin = '';
      _state = _PinState.entry;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unlocked = _state == _PinState.unlocked;
    final dotColor = switch (_state) {
      _PinState.wrong => AppColors.danger,
      _PinState.unlocked => AppColors.accent,
      _PinState.entry => AppColors.text,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SafeAnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Row(
            key: ValueKey(unlocked),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                unlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                size: 18,
                color: unlocked ? AppColors.accent : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                unlocked ? 'Unlocked' : 'Enter PIN',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: unlocked ? AppColors.accent : AppColors.text,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Shaker(
          controller: _shake,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOut,
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 9),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length ? dotColor : Colors.transparent,
                    border: Border.all(
                      color: i < _pin.length ? dotColor : AppColors.outlineStrong,
                      width: 1.5,
                    ),
                    boxShadow: [
                      if (unlocked)
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.6),
                          blurRadius: 10,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Hint: 2580 — straight down the middle',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        IgnorePointer(
          ignoring: unlocked,
          child: AnimatedOpacity(
            opacity: unlocked ? 0.3 : 1,
            duration: const Duration(milliseconds: 220),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final row in _rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final key in row)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 9),
                            child: switch (key) {
                              '' => const SizedBox(width: 62, height: 62),
                              '<' => _Key(
                                  onDown: _backspace,
                                  child: const Icon(
                                    Icons.backspace_outlined,
                                    size: 20,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              _ => _Key(
                                  onDown: () => _digit(key),
                                  child: Text(
                                    key,
                                    style: theme.textTheme.headlineSmall,
                                  ),
                                ),
                            },
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (unlocked)
          TextButton.icon(
            onPressed: _lock,
            icon: const Icon(Icons.lock_rounded, size: 18),
            label: const Text('Lock again'),
          ),
      ],
    );
  }
}

/// A key that acts on touch-down, like a hardware key.
class _Key extends StatefulWidget {
  const _Key({required this.onDown, required this.child});

  final VoidCallback onDown;
  final Widget child;

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        _set(true);
        widget.onDown();
      },
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.9 : 1,
        duration: const Duration(milliseconds: 90),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: 62,
          height: 62,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _down ? AppColors.surfaceHighest : AppColors.surfaceRaised,
            border: Border.all(
              color: _down
                  ? AppColors.accent.withValues(alpha: 0.5)
                  : AppColors.outline,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
