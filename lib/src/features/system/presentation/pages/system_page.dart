import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptic_registry.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptic_tracer.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptics_providers.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/code_block.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/haptic_echo.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/pill_tag.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/safe_animated_switcher.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/tactile_card.dart';
import 'package:flutter_haptics_showcase/src/features/system/data/system_catalog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Every constant iOS and Android define, playable one by one through
/// `FlutterHaptics.playSystem` — and the honest answer when one can't play.
class SystemPage extends ConsumerStatefulWidget {
  const SystemPage({super.key});

  @override
  ConsumerState<SystemPage> createState() => _SystemPageState();
}

class _SystemPageState extends ConsumerState<SystemPage> {
  late TargetPlatform _shown = defaultTargetPlatform == TargetPlatform.android
      ? TargetPlatform.android
      : TargetPlatform.iOS;

  final Map<SystemHaptic, _Result> _results = {};
  final Map<SystemHaptic, int> _taps = {};

  static const _snippet = r'''
// One platform's own constant, on that platform only.
await FlutterHaptics.playSystem(AndroidHaptic.toggleOn); // Android
await FlutterHaptics.playSystem(IOSHaptic.impactRigid);  // iOS

// playSystem never falls back: wrong platform or an OS older than the
// constant → HapticRoute.none. To cross platforms, pair them in an intent:
static const switchOn = HapticIntent(
  ios: HapticArm.native(IOSHaptic.impactLight),
  android: HapticArm.native(AndroidHaptic.toggleOn), // API 34
  pattern: AppPatterns.switchOn,                     // recovery below that
);

// Where a platform names nothing for the meaning, say so in the arm:
static const caution = HapticIntent(
  ios: HapticArm.native(IOSHaptic.notificationWarning),
  android: HapticArm.pattern(), // no warning constant: the pattern, by choice
  pattern: HapticPatterns.warning,
);
await FlutterHaptics.perform(AppHaptics.switchOn);''';

  bool get _onThisPlatform => _shown == defaultTargetPlatform;

  List<SystemEntry> get _entries =>
      _shown == TargetPlatform.iOS ? SystemCatalog.ios : SystemCatalog.android;

  Future<void> _play(SystemEntry entry) async {
    final haptic = entry.haptic;
    setState(() => _taps[haptic] = (_taps[haptic] ?? 0) + 1);
    final route = await FlutterHaptics.playSystem(haptic);
    final reason = await _reasonFor(haptic, route);
    if (!mounted) return;
    setState(() => _results[haptic] = _Result(route, reason));
  }

  /// Why nothing played, in the platform's own words where there are some.
  Future<String?> _reasonFor(SystemHaptic haptic, HapticRoute route) async {
    if (route != HapticRoute.none) return null;
    if (!FlutterHaptics.enabled) return 'haptics are switched off in Settings';
    if (haptic.platform != defaultTargetPlatform) {
      return 'belongs to ${haptic.platform.name} — playSystem never falls back';
    }
    // The tracer saw the decline; its reason reaches the log a microtask on.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return null;
    final log = ref.read(hapticLogProvider);
    for (final trace in log.reversed) {
      if (trace.kind == HapticTraceKind.system && trace.system == haptic) {
        return trace.reason.isEmpty ? null : trace.reason;
      }
    }
    return null;
  }

  void _show(TargetPlatform platform) {
    if (platform == _shown) return;
    FlutterHaptics.perform(AppHaptics.tick);
    setState(() => _shown = platform);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _entries;
    final groups = <String>{for (final e in entries) e.group}.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('System vocabulary')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Text(
            'The constants each OS defines and each vendor tuned. '
            'playSystem plays exactly one, on its own platform only — so it '
            'feels like the rest of the phone, not like an app imitating it.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<TargetPlatform>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: TargetPlatform.iOS,
                icon: const Icon(Icons.phone_iphone_rounded, size: 18),
                label: Text('iOS · ${SystemCatalog.ios.length}'),
              ),
              ButtonSegment(
                value: TargetPlatform.android,
                icon: const Icon(Icons.android_rounded, size: 18),
                label: Text('Android · ${SystemCatalog.android.length}'),
              ),
            ],
            selected: {_shown},
            onSelectionChanged: (s) => _show(s.first),
          ),
          const SizedBox(height: 12),
          _PlatformBanner(onThisPlatform: _onThisPlatform, shown: _shown),
          for (final group in groups) ...[
            const SizedBox(height: 22),
            Text(group.toUpperCase(), style: AppTypography.eyebrow),
            const SizedBox(height: 10),
            for (final entry in entries.where((e) => e.group == group)) ...[
              _ConstantTile(
                entry: entry,
                taps: _taps[entry.haptic] ?? 0,
                result: _results[entry.haptic],
                onTap: () => _play(entry),
              ),
              const SizedBox(height: 10),
            ],
          ],
          const SizedBox(height: 18),
          const Text('HOW APPHAPTICS PAIRS THEM', style: AppTypography.eyebrow),
          const SizedBox(height: 10),
          const _PairingTable(),
          const SizedBox(height: 24),
          const Text('CODE', style: AppTypography.eyebrow),
          const SizedBox(height: 10),
          const CodeBlock(_snippet),
        ],
      ),
    );
  }
}

class _Result {
  const _Result(this.route, this.reason);

  final HapticRoute route;
  final String? reason;
}

class _PlatformBanner extends StatelessWidget {
  const _PlatformBanner({required this.onThisPlatform, required this.shown});

  final bool onThisPlatform;
  final TargetPlatform shown;

  @override
  Widget build(BuildContext context) {
    final color = onThisPlatform ? AppColors.system : AppColors.warning;
    final other = shown == TargetPlatform.iOS ? 'iOS' : 'Android';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            onThisPlatform
                ? Icons.touch_app_rounded
                : Icons.do_not_touch_outlined,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              onThisPlatform
                  ? defaultTargetPlatform == TargetPlatform.iOS
                      ? 'Tap any constant to feel it. All nine predate iOS 15, '
                          'this package\'s minimum, so none is too new for '
                          'this phone.'
                      : 'Tap any constant to feel it. Some need a newer OS '
                          'than this phone has — those answer none, with the '
                          'reason.'
                  : 'These are $other\'s constants. On this phone '
                      'playSystem returns none for every one of them — on '
                      'purpose. Tap one to see; use an intent to cross '
                      'platforms.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConstantTile extends StatelessWidget {
  const _ConstantTile({
    required this.entry,
    required this.taps,
    required this.result,
    required this.onTap,
  });

  final SystemEntry entry;
  final int taps;
  final _Result? result;
  final VoidCallback onTap;

  static Color _colorFor(HapticRoute? route) => switch (route) {
        HapticRoute.system => AppColors.system,
        HapticRoute.pattern => AppColors.pattern,
        HapticRoute.none => AppColors.silent,
        null => AppColors.textFaint,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outcome = result;
    final color = _colorFor(outcome?.route);
    final usedBy = entry.usedBy;

    return TactileCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HapticEcho(
            trigger: taps,
            color: color == AppColors.textFaint ? AppColors.system : color,
            spread: 1.7,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.system.withValues(alpha: 0.12),
                border: Border.all(
                  color: AppColors.system.withValues(alpha: 0.35),
                ),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: AppColors.system,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.haptic.name,
                        style: AppTypography.mono.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    PillTag(
                      entry.availability,
                      color: AppColors.textMuted,
                      uppercase: false,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  entry.native,
                  style: AppTypography.mono.copyWith(
                    fontSize: 10.5,
                    color: AppColors.textFaint,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  entry.meaning,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.text),
                ),
                if (entry.note != null) ...[
                  const SizedBox(height: 4),
                  Text(entry.note!, style: theme.textTheme.bodySmall),
                ],
                if (usedBy.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final name in usedBy)
                        PillTag(
                          name,
                          color: AppColors.accent,
                          uppercase: false,
                        ),
                    ],
                  ),
                ],
                if (outcome != null) ...[
                  const SizedBox(height: 8),
                  SafeAnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Row(
                      key: ValueKey(taps),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            outcome.reason == null
                                ? '→ ${outcome.route.name}'
                                : '→ ${outcome.route.name} · ${outcome.reason}',
                            style: AppTypography.mono.copyWith(
                              fontSize: 10.5,
                              height: 1.35,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Meaning → iOS → Android, for every intent the app defines.
class _PairingTable extends StatelessWidget {
  const _PairingTable();

  @override
  Widget build(BuildContext context) {
    final rows = HapticRegistry.intents.entries.toList();
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Row(
              children: [
                Expanded(flex: 4, child: Text('MEANING', style: AppTypography.eyebrow)),
                Expanded(flex: 5, child: Text('IOS', style: AppTypography.eyebrow)),
                Expanded(flex: 6, child: Text('ANDROID', style: AppTypography.eyebrow)),
              ],
            ),
          ),
          for (final row in rows) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      row.key,
                      style: AppTypography.mono.copyWith(
                        fontSize: 11,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  Expanded(flex: 5, child: _Cell(row.value.ios)),
                  Expanded(flex: 6, child: _Cell(row.value.android)),
                ],
              ),
            ),
          ],
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 9, 14, 12),
            child: Text(
              'pattern means the platform names no constant for that meaning, '
              'so the intent plays its pattern there on purpose. A constant '
              'with an API level above 24 recovers with the pattern below it.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.arm);

  final HapticArm<SystemHaptic> arm;

  @override
  Widget build(BuildContext context) {
    final h = switch (arm) {
      NativeArm(:final haptic) => haptic,
      _ => null,
    };
    if (h == null) {
      return Text(
        arm is PatternArm ? 'pattern' : 'silent',
        style: AppTypography.mono.copyWith(
          fontSize: 11,
          color: arm is PatternArm ? AppColors.pattern : AppColors.textFaint,
        ),
      );
    }
    final api = h.platform == TargetPlatform.android && h.minimumVersion > 24
        ? ' ${h.minimumVersion}'
        : '';
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: h.name),
          if (api.isNotEmpty)
            TextSpan(
              text: api,
              style: const TextStyle(color: AppColors.warning, fontSize: 9),
            ),
        ],
      ),
      style: AppTypography.mono.copyWith(fontSize: 11),
    );
  }
}
