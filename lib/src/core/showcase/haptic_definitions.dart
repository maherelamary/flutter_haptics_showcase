import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_typography.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptic_registry.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptic_source.dart';
import 'package:flutter_haptics_showcase/src/core/showcase/showcase_entry.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/code_block.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/pattern_waveform.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/pill_tag.dart';

/// "What these resolve to": every intent and pattern an entry mentions, read
/// from the live values — what iOS plays, what Android plays and from which
/// API level, the fallback pattern and its waveform — plus the declarations
/// to copy.
///
/// Generated, so every entry gets the same depth and it can never drift from
/// `AppHaptics` / `AppPatterns`.
class HapticDefinitions extends StatelessWidget {
  const HapticDefinitions({
    super.key,
    required this.references,
    this.accent = AppColors.accent,
  });

  /// The references in an entry's code and haptic map.
  static List<HapticReference> of(ShowcaseEntry entry) => HapticRegistry.scan(
        [
          entry.code,
          for (final m in entry.moments) '${m.feedback} ${m.note ?? ''}',
        ].join('\n'),
      );

  final List<HapticReference> references;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (references.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final reference in references) ...[
          _DefinitionCard(reference: reference, accent: accent),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 4),
        CodeBlock(
          HapticSource.declarations(references),
          label: 'definitions.dart',
        ),
      ],
    );
  }
}

class _DefinitionCard extends StatelessWidget {
  const _DefinitionCard({required this.reference, required this.accent});

  final HapticReference reference;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final intent = reference.intent;
    final pattern = reference.pattern;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  reference.name,
                  style: AppTypography.mono.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              PillTag(
                intent != null ? 'intent' : 'pattern',
                color: intent != null ? AppColors.system : AppColors.pattern,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (intent != null)
            ..._intentRows(context, intent)
          else if (pattern != null)
            ..._patternRows(context, pattern),
        ],
      ),
    );
  }

  List<Widget> _intentRows(BuildContext context, HapticIntent intent) {
    final android = intent.android;
    final api = android is NativeArm<AndroidHaptic>
        ? android.haptic.minimumVersion
        : null;
    return [
      _armRow('iOS', intent.ios),
      _armRow('Android', android, trailing: api == null ? null : 'API $api+'),
      _Row(
        label: 'Pattern',
        value: HapticRegistry.nameOf(intent.pattern) ?? 'custom',
        waveform: intent.pattern,
      ),
      const SizedBox(height: 6),
      Text(
        _explain(intent, api),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ];
  }

  static _Row _armRow(
    String label,
    HapticArm<SystemHaptic> arm, {
    String? trailing,
  }) =>
      switch (arm) {
        NativeArm(:final haptic) =>
          _Row(label: label, value: haptic.name, trailing: trailing),
        PatternArm() =>
          _Row(label: label, value: 'the pattern, by choice'),
        SilentArm() =>
          _Row(label: label, value: 'silent, by choice', muted: true),
      };

  /// What the pattern is for in this intent, in a sentence or two.
  static String _explain(HapticIntent intent, int? androidApi) {
    final arms = {'iOS': intent.ios, 'Android': intent.android};
    final chosen = [
      for (final e in arms.entries)
        if (e.value is PatternArm) e.key,
    ];
    final silent = [
      for (final e in arms.entries)
        if (e.value is SilentArm) e.key,
    ];
    final native = arms.values.whereType<NativeArm<SystemHaptic>>().isNotEmpty;

    return [
      if (chosen.isNotEmpty)
        '${chosen.join(' and ')} ${chosen.length > 1 ? 'name' : 'names'} no '
            'constant for this, so the pattern plays there on purpose.',
      if (silent.isNotEmpty)
        '${silent.join(' and ')} ${silent.length > 1 ? 'play' : 'plays'} '
            'nothing here, on purpose.',
      if (native && androidApi != null && androidApi > HapticSource.minSdk)
        'Where a constant is named, the pattern recovers below API '
            '$androidApi and on basic vibration motors that can\'t render it.'
      else if (native)
        'Where a constant is named, the pattern plays only if it can\'t be '
            'delivered — a basic vibration motor, or an OS that declines.',
    ].join(' ');
  }

  List<Widget> _patternRows(BuildContext context, HapticPattern pattern) {
    return [
      PatternWaveform(
        pattern: pattern,
        color: accent,
        height: 40,
        minDuration: const Duration(milliseconds: 300),
      ),
      const SizedBox(height: 8),
      Text(
        [
          HapticSource.summary(pattern),
          if (reference.owner == 'HapticPatterns') 'built into flutter_haptics',
        ].join(' · '),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ];
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.trailing,
    this.waveform,
    this.muted = false,
  });

  final String label;
  final String value;
  final String? trailing;
  final HapticPattern? waveform;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final wave = waveform;
    final note = trailing;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.mono.copyWith(
                fontSize: 12,
                color: muted ? AppColors.textFaint : AppColors.text,
              ),
            ),
          ),
          if (note != null)
            Text(
              note,
              style: AppTypography.eyebrow.copyWith(fontSize: 9.5),
            ),
          if (wave != null)
            SizedBox(
              width: 64,
              child: PatternWaveform(
                pattern: wave,
                height: 18,
                showBaseline: false,
                color: AppColors.pattern,
              ),
            ),
        ],
      ),
    );
  }
}
