import 'package:flutter/material.dart';

/// Flutter Haptics Tactile's palette: near-black surfaces, one vivid accent.
///
/// Three colours carry meaning everywhere in the app and never decorate:
/// [system] (the OS played its own feedback), [pattern] (a synthesised
/// waveform played) and [silent] (nothing played).
abstract final class AppColors {
  // Surfaces, darkest to lightest.
  static const background = Color(0xFF09090B);
  static const surface = Color(0xFF121216);
  static const surfaceRaised = Color(0xFF1A1A20);
  static const surfaceHighest = Color(0xFF24242C);
  static const outline = Color(0xFF26262E);
  static const outlineStrong = Color(0xFF393943);

  // Text.
  static const text = Color(0xFFF4F4F6);
  static const textMuted = Color(0xFF9A9AA6);
  static const textFaint = Color(0xFF62626E);

  // The accent.
  static const accent = Color(0xFFD4FF3A);
  static const onAccent = Color(0xFF0B0B0D);

  // Routes — what a haptic call actually did.
  static const system = Color(0xFF5EEAD4);
  static const pattern = accent;
  static const silent = Color(0xFF5A5A66);

  // Status.
  static const success = Color(0xFF3DDC97);
  static const warning = Color(0xFFFFB547);
  static const danger = Color(0xFFFF5A5F);
  static const info = Color(0xFF7AA7FF);

  // Pillar tints — identity only, used sparingly.
  static const gallery = accent;
  static const lab = Color(0xFFFF7A45);
  static const flows = Color(0xFF7AA7FF);
  static const studio = Color(0xFFC792FF);
}
