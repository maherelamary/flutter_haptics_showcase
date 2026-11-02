import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/controls/route_readout.dart';

/// Four buttons, four levels of feedback — including none.
class ButtonFamilyDemo extends StatefulWidget {
  const ButtonFamilyDemo({super.key});

  @override
  State<ButtonFamilyDemo> createState() => _ButtonFamilyDemoState();
}

class _ButtonFamilyDemoState extends State<ButtonFamilyDemo> {
  HapticRoute? _primary;
  HapticRoute? _secondary;
  HapticRoute? _destructive;
  String _destructiveCall = 'perform(caution) on open';
  bool _flashing = false;

  Future<void> _onPrimary() async {
    final route = await FlutterHaptics.perform(AppHaptics.press);
    if (mounted) setState(() => _primary = route);
  }

  Future<void> _onSecondary() async {
    final route = await FlutterHaptics.perform(AppHaptics.tap);
    if (mounted) setState(() => _secondary = route);
  }

  Future<void> _onDestructive() async {
    // The warning lands as the question appears, not after it is answered.
    final warned = await FlutterHaptics.perform(AppHaptics.caution);
    if (!mounted) return;
    setState(() {
      _destructiveCall = 'perform(caution)';
      _destructive = warned;
    });

    final confirmed = await showDialog<HapticRoute>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'Everything you have saved goes with it. This cannot be undone.',
        ),
        actions: [
          // Backing out of a destructive action is silent: nothing happened.
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final route = await FlutterHaptics.perform(AppHaptics.press);
              if (context.mounted) Navigator.of(context).pop(route);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted) return;

    if (confirmed == null) {
      setState(() {
        _destructiveCall = 'cancelled — silent';
        _destructive = null;
      });
      return;
    }
    setState(() {
      _destructiveCall = 'perform(press)';
      _destructive = confirmed;
      _flashing = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (mounted) setState(() => _flashing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Slot(
          label: 'Primary',
          readout: RouteReadout(call: 'perform(press)', route: _primary),
          child: FilledButton(
            onPressed: _onPrimary,
            child: const Text('Save changes'),
          ),
        ),
        _Slot(
          label: 'Secondary',
          readout: RouteReadout(call: 'perform(tap)', route: _secondary),
          child: OutlinedButton(
            onPressed: _onSecondary,
            child: const Text('Preview'),
          ),
        ),
        _Slot(
          label: 'Destructive',
          readout: RouteReadout(
            call: _destructiveCall,
            route: _destructive,
            silent: _destructiveCall.contains('silent'),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.danger.withValues(
                    alpha: _flashing ? 0.6 : 0,
                  ),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _flashing
                    ? AppColors.danger
                    : AppColors.danger.withValues(alpha: 0.16),
                foregroundColor: _flashing ? Colors.white : AppColors.danger,
              ),
              onPressed: _onDestructive,
              child: const Text('Delete account'),
            ),
          ),
        ),
        const _Slot(
          label: 'Disabled',
          readout: RouteReadout(call: 'silent by design', silent: true),
          last: true,
          child: FilledButton(onPressed: null, child: Text('Submit')),
        ),
      ],
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.label,
    required this.readout,
    required this.child,
    this.last = false,
  });

  final String label;
  final Widget readout;
  final Widget child;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label.toUpperCase(), style: AppTypography.eyebrow),
          const SizedBox(height: 8),
          child,
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerLeft, child: readout),
        ],
      ),
    );
  }
}
