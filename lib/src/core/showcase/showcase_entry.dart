import 'package:flutter/material.dart';

/// One line of a demo's haptic map: when this happens, that is felt.
@immutable
class HapticMoment {
  const HapticMoment(this.trigger, this.feedback, {this.note});

  /// What the user does, in their words: "Drag past a notch".
  final String trigger;

  /// What plays, in code words: "AppHaptics.detent".
  final String feedback;

  /// Optional nuance: "API 34+, pattern below".
  final String? note;
}

/// A self-contained demo in the Gallery or the Lab.
@immutable
class ShowcaseEntry {
  const ShowcaseEntry({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.rationale,
    required this.moments,
    required this.code,
    required this.builder,
    this.icon = Icons.touch_app_outlined,
    this.immersive = false,
    this.tags = const [],
  });

  /// URL-safe identifier, unique within its catalog: `detent-slider`.
  final String id;
  final String title;

  /// Grouping in the catalog list: "Selection", "Gestures"…
  final String category;

  /// One sentence shown in lists and under the title.
  final String summary;

  /// The UX reasoning: why this feel, why here, what was left out.
  final String rationale;

  /// The haptic map: every moment that plays something.
  final List<HapticMoment> moments;

  /// The essential code, trimmed to what a client app would copy.
  final String code;

  /// Builds the live demo.
  final WidgetBuilder builder;

  final IconData icon;

  /// Full-screen demo; the explanation moves into an info sheet.
  final bool immersive;

  /// Short labels, e.g. `register()`, `API 34`, `stop()`.
  final List<String> tags;
}
