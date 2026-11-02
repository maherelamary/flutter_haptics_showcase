import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/fidelity_simulator.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptics_providers.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/code_block.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/tactile_card.dart';
import 'package:flutter_haptics_showcase/src/features/home/presentation/widgets/device_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const _switchCode = '''
// A client app's version, simplified. This app's own notifier, which also
// stores the Island and tier settings, is in haptics_providers.dart.
class HapticsSettings extends Notifier<bool> {
  @override
  bool build() {
    final on = ref.watch(sharedPreferencesProvider).getBool('haptics') ?? true;
    FlutterHaptics.enabled = on; // the package gates every call
    return on;
  }

  Future<void> set(bool on) async {
    if (!on) {
      await FlutterHaptics.stop(); // silence anything already playing
      await FlutterHaptics.perform(AppHaptics.switchOff);
    }
    state = on;
    FlutterHaptics.enabled = on;
    if (on) FlutterHaptics.perform(AppHaptics.switchOn);
    await ref.read(sharedPreferencesProvider).setBool('haptics', on);
  }
}''';

  Future<void> _setEnabled(WidgetRef ref, bool on) async {
    final notifier = ref.read(hapticsSettingsProvider.notifier);
    // Feel the switch go off *before* haptics are disabled, and come on
    // after they are enabled — the setting confirms itself either way.
    // Switching off also silences whatever is still playing, first, so the
    // stop cannot cut the confirming tap short.
    if (!on) {
      await FlutterHaptics.stop();
      await FlutterHaptics.perform(AppHaptics.switchOff);
    }
    await notifier.setEnabled(on);
    if (on) FlutterHaptics.perform(AppHaptics.switchOn);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(hapticsSettingsProvider);
    final notifier = ref.read(hapticsSettingsProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          const DeviceCard(detailed: true),
          const SizedBox(height: 24),
          const Text('PREFERENCES', style: AppTypography.eyebrow),
          const SizedBox(height: 10),
          TactileCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Haptics'),
                  subtitle: const Text(
                    'The app-wide switch. Drives FlutterHaptics.enabled — no '
                    'call site checks it.',
                  ),
                  value: settings.enabled,
                  onChanged: (on) => _setEnabled(ref, on),
                ),
                const Divider(indent: 16, endIndent: 16),
                SwitchListTile(
                  title: const Text('Haptic Island'),
                  subtitle: const Text(
                    'Show each haptic at the top of the screen, for demos '
                    'and screen recordings.',
                  ),
                  value: settings.showIsland,
                  onChanged: (on) {
                    FlutterHaptics.perform(
                      on ? AppHaptics.switchOn : AppHaptics.switchOff,
                    );
                    notifier.setShowIsland(on);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('SIMULATE A CHEAPER PHONE', style: AppTypography.eyebrow),
          const SizedBox(height: 10),
          TactileCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<SimulatedTier>(
                  showSelectedIcon: false,
                  segments: [
                    for (final tier in SimulatedTier.values)
                      ButtonSegment(value: tier, label: Text(tier.label)),
                  ],
                  selected: {settings.tier},
                  onSelectionChanged: (selection) {
                    FlutterHaptics.perform(AppHaptics.tick);
                    notifier.setTier(selection.first);
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  settings.tier.explanation,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Applies app-wide. Try the Gallery on Rhythm: the patterns '
                  'designed around timing still read; the ones that relied on '
                  'sharpness flatten out.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('HOW THE SWITCH IS WIRED', style: AppTypography.eyebrow),
          const SizedBox(height: 10),
          const CodeBlock(_switchCode),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Flutter Haptics Tactile · built on flutter_haptics 1.0',
              textAlign: TextAlign.center,
              style: AppTypography.eyebrow.copyWith(color: AppColors.textFaint),
            ),
          ),
        ],
      ),
    );
  }
}
