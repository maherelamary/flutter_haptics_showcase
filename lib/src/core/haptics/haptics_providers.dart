import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/fidelity_simulator.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptic_tracer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main()` with the instance loaded before the first frame.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override sharedPreferencesProvider'),
);

/// Overridden in `main()` with the tracer installed as the haptics platform.
final hapticTracerProvider = Provider<TracingHapticsPlatform>(
  (ref) => throw UnimplementedError('Override hapticTracerProvider'),
);

/// What this device can reproduce. Queried once by the package and cached.
final hapticSupportProvider = FutureProvider<HapticSupport>(
  (ref) => FlutterHaptics.support,
);

/// The user's haptics preferences.
@immutable
class HapticsSettings {
  const HapticsSettings({
    required this.enabled,
    required this.showIsland,
    required this.tier,
  });

  /// The app-wide switch, mirrored into `FlutterHaptics.enabled`.
  final bool enabled;

  /// Whether the Haptic Island shows each haptic on screen.
  final bool showIsland;

  /// The device tier being imitated.
  final SimulatedTier tier;

  HapticsSettings copyWith({
    bool? enabled,
    bool? showIsland,
    SimulatedTier? tier,
  }) =>
      HapticsSettings(
        enabled: enabled ?? this.enabled,
        showIsland: showIsland ?? this.showIsland,
        tier: tier ?? this.tier,
      );
}

/// Owns the haptics settings: persists them, and pushes them into the
/// package so no call site ever checks a preference.
///
/// This is the whole of the Riverpod integration a client app needs. Call
/// sites keep calling `FlutterHaptics.perform(...)` directly; the package's
/// `enabled` switch does the gating.
class HapticsSettingsNotifier extends Notifier<HapticsSettings> {
  static const enabledKey = 'haptics.enabled';
  static const islandKey = 'haptics.island';
  static const tierKey = 'haptics.tier';

  @override
  HapticsSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final settings = HapticsSettings(
      enabled: prefs.getBool(enabledKey) ?? true,
      showIsland: prefs.getBool(islandKey) ?? true,
      tier: _tierFrom(prefs.getString(tierKey)),
    );
    _apply(settings);
    return settings;
  }

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    _apply(state);
    await _prefs.setBool(enabledKey, value);
  }

  Future<void> setShowIsland(bool value) async {
    state = state.copyWith(showIsland: value);
    await _prefs.setBool(islandKey, value);
  }

  Future<void> setTier(SimulatedTier value) async {
    state = state.copyWith(tier: value);
    _apply(state);
    await _prefs.setString(tierKey, value.name);
  }

  void _apply(HapticsSettings settings) {
    FlutterHaptics.enabled = settings.enabled;
    ref.read(hapticTracerProvider).tier = settings.tier;
  }

  static SimulatedTier _tierFrom(String? name) {
    for (final tier in SimulatedTier.values) {
      if (tier.name == name) return tier;
    }
    return SimulatedTier.native;
  }
}

final hapticsSettingsProvider =
    NotifierProvider<HapticsSettingsNotifier, HapticsSettings>(
  HapticsSettingsNotifier.new,
);

/// The most recent haptics, newest last — for recaps and the log sheet.
class HapticLogNotifier extends Notifier<List<HapticTrace>> {
  static const capacity = 300;

  @override
  List<HapticTrace> build() {
    final subscription =
        ref.watch(hapticTracerProvider).traces.listen(_record);
    ref.onDispose(subscription.cancel);
    return const [];
  }

  void _record(HapticTrace trace) {
    final next = [...state, trace];
    state = next.length > capacity
        ? next.sublist(next.length - capacity)
        : next;
  }

  /// Traces recorded at or after [since].
  List<HapticTrace> since(DateTime since) =>
      state.where((t) => !t.at.isBefore(since)).toList();

  void clear() => state = const [];
}

final hapticLogProvider =
    NotifierProvider<HapticLogNotifier, List<HapticTrace>>(
  HapticLogNotifier.new,
);
