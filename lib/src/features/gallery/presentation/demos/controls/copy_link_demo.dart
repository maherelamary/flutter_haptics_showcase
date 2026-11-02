import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/safe_animated_switcher.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/controls/route_readout.dart';

/// A share link with a copy button that only speaks when something changed.
class CopyLinkDemo extends StatefulWidget {
  const CopyLinkDemo({super.key});

  @override
  State<CopyLinkDemo> createState() => _CopyLinkDemoState();
}

class _CopyLinkDemoState extends State<CopyLinkDemo> {
  static const _link = 'https://tactile.app/s/7Hk2Qa';
  static const _window = Duration(milliseconds: 1500);

  Timer? _reset;
  bool _copied = false;
  String _call = 'perform(tap)';
  HapticRoute? _route;
  bool _silent = false;

  Future<void> _copy() async {
    if (_copied) {
      // Already on the clipboard: the check mark is still showing, so a
      // second buzz would report an event that did not happen.
      setState(() {
        _call = 'already copied — silent';
        _silent = true;
      });
      return;
    }
    await Clipboard.setData(const ClipboardData(text: _link));
    final route = await FlutterHaptics.perform(AppHaptics.tap);
    if (!mounted) return;
    setState(() {
      _copied = true;
      _call = 'perform(tap)';
      _route = route;
      _silent = false;
    });
    _reset?.cancel();
    _reset = Timer(_window, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Invite link', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Anyone with the link can view this board.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _copied ? AppColors.accent : AppColors.outline,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.link_rounded,
                size: 18,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _link,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.mono.copyWith(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  color: _copied ? AppColors.accent : AppColors.surfaceHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  tooltip: 'Copy link',
                  onPressed: _copy,
                  icon: SafeAnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: child,
                    ),
                    child: Icon(
                      _copied ? Icons.check_rounded : Icons.copy_rounded,
                      key: ValueKey(_copied),
                      size: 18,
                      color: _copied ? AppColors.onAccent : AppColors.text,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        RouteReadout(call: _call, route: _route, silent: _silent),
      ],
    );
  }
}
