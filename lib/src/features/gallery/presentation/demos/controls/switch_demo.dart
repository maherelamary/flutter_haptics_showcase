import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/controls/route_readout.dart';

/// Three settings switches whose on and off feel different.
class SwitchDemo extends StatefulWidget {
  const SwitchDemo({super.key});

  @override
  State<SwitchDemo> createState() => _SwitchDemoState();
}

class _SwitchDemoState extends State<SwitchDemo> {
  final List<(IconData, String, bool)> _rows = [
    (Icons.notifications_rounded, 'Notifications', true),
    (Icons.location_on_rounded, 'Location', false),
    (Icons.cloud_sync_rounded, 'Auto-backup', true),
  ];

  String _call = 'flip a switch';
  HapticRoute? _route;

  Future<void> _set(int index, bool on) async {
    final (icon, label, _) = _rows[index];
    setState(() {
      _rows[index] = (icon, label, on);
      _call = on ? 'perform(switchOn)' : 'perform(switchOff)';
      _route = null;
    });
    final route = await FlutterHaptics.perform(
      on ? AppHaptics.switchOn : AppHaptics.switchOff,
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
              for (var i = 0; i < _rows.length; i++) ...[
                if (i > 0) const Divider(indent: 52),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _rows[i].$3
                              ? AppColors.accent.withValues(alpha: 0.16)
                              : AppColors.surfaceHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _rows[i].$1,
                          size: 16,
                          color: _rows[i].$3
                              ? AppColors.accent
                              : AppColors.textFaint,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _rows[i].$2,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      Switch(
                        value: _rows[i].$3,
                        onChanged: (on) => _set(i, on),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        RouteReadout(call: _call, route: _route),
      ],
    );
  }
}
