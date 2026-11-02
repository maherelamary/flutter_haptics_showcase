import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/fidelity_simulator.dart';

/// What reached the platform for one haptic request.
enum HapticTraceKind {
  /// A synthesised pattern, via `play` or an intent's recovery.
  pattern,

  /// One of the platform's own constants, via `playSystem` or `perform`.
  system,

  /// A registered handle replayed. A handle that paced a call out never gets
  /// this far, so a drag fast enough to be throttled shows fewer of these.
  replay,
}

/// One request, as the platform saw it.
@immutable
class HapticTrace {
  const HapticTrace({
    required this.id,
    required this.kind,
    required this.at,
    required this.played,
    this.pattern,
    this.system,
    this.reason = '',
    this.tier = SimulatedTier.native,
    this.recoveredFrom,
  });

  final int id;
  final HapticTraceKind kind;
  final DateTime at;

  /// Whether it reached the actuator.
  final bool played;

  /// The pattern that was rendered — after any tier simulation.
  final HapticPattern? pattern;

  /// The constant requested, for [HapticTraceKind.system].
  final SystemHaptic? system;

  /// Why nothing played, when [played] is false.
  final String reason;

  /// The tier being imitated when this played.
  final SimulatedTier tier;

  /// For a pattern `perform` played because its native constant was
  /// declined: the declined request. Marked by the tracer, which sees the
  /// two arrive in order, rather than guessed from timing afterwards.
  final HapticTrace? recoveredFrom;
}

/// A [FlutterHapticsPlatform] that forwards everything to the real one and
/// reports what went through.
///
/// This is the package's own test seam put to work in a running app:
/// [FlutterHaptics] stays a thin facade over `FlutterHapticsPlatform.instance`,
/// so wrapping the instance makes every haptic observable without changing a
/// single call site. Flutter Haptics Tactile uses it for the Haptic Island and flow recaps, so
/// haptics are visible in screen recordings and on simulators.
///
/// It also imitates cheaper hardware: set [tier] and every pattern is
/// degraded before it reaches the actuator — except one marked with
/// [pinTier], which plays at its own tier instead.
class TracingHapticsPlatform extends FlutterHapticsPlatform {
  TracingHapticsPlatform(this._inner);

  final FlutterHapticsPlatform _inner;
  final StreamController<HapticTrace> _traces =
      StreamController<HapticTrace>.broadcast();
  final Map<int, HapticPattern> _registered = {};
  final Expando<SimulatedTier> _pinned = Expando('pinned tier');
  int _nextId = 0;

  /// A constant `perform` asked for and was refused. Its pattern is the next
  /// `play`; anything else in between means it never came.
  HapticTrace? _awaitingRecovery;

  /// The device tier to imitate. [SimulatedTier.native] plays as-is.
  SimulatedTier tier = SimulatedTier.native;

  /// Marks [pattern] to play at [tier] whatever the app-wide [this.tier] is,
  /// and returns it — for a preview that lets you pick the tier, so it is
  /// simulated once rather than twice.
  ///
  /// The mark sticks to this instance, so pin a pattern built for this one
  /// play, never a shared constant.
  HapticPattern pinTier(HapticPattern pattern, SimulatedTier tier) {
    _pinned[pattern] = tier;
    return pattern;
  }

  /// Every request, as it happens.
  Stream<HapticTrace> get traces => _traces.stream;

  @override
  Future<HapticSupport> querySupport() => _inner.querySupport();

  @override
  Future<NativeResult> play(HapticPattern pattern) {
    final recovering = _awaitingRecovery;
    _awaitingRecovery = null;
    return _playDegraded(
      pattern,
      traceFailure: true,
      recoveredFrom: recovering,
    );
  }

  Future<NativeResult> _playDegraded(
    HapticPattern pattern, {
    required bool traceFailure,
    HapticTraceKind kind = HapticTraceKind.pattern,
    HapticTrace? recoveredFrom,
  }) async {
    final tier = _pinned[pattern] ?? this.tier;
    final rendered = FidelitySimulator.degrade(pattern, tier);
    final result = rendered.events.isEmpty
        ? const NativeResult.failed('nothing left to play on this tier')
        : await _inner.play(rendered);
    if (!result.played && !traceFailure) return result;
    _emit(
      kind: kind,
      played: result.played,
      reason: result.reason,
      pattern: rendered,
      tier: tier,
      recoveredFrom: recoveredFrom,
    );
    return result;
  }

  @override
  Future<NativeResult> playSystem(
    SystemHaptic haptic, {
    required bool requirePerceptible,
  }) async {
    final NativeResult result;
    if (tier == SimulatedTier.rhythm && requirePerceptible) {
      // What the plugin does on a real rhythm-tier device: `perform` has a
      // pattern to fall back on, so a constant that might not be felt is
      // declined. `playSystem` is passed through, as the plugin passes it —
      // though no simulation can make a flagship render a constant as
      // faintly as a rotary motor would.
      result = const NativeResult.failed(
        'simulated rhythm tier: perform skips constants for its pattern',
      );
    } else {
      result = await _inner.playSystem(
        haptic,
        requirePerceptible: requirePerceptible,
      );
    }
    final trace = _emit(
      kind: HapticTraceKind.system,
      played: result.played,
      reason: result.reason,
      system: haptic,
    );
    // Only `perform` asks with requirePerceptible, and only a decline sends
    // it to its pattern: a silenced answer (the user's own setting) does not.
    _awaitingRecovery =
        requirePerceptible && !result.played && !result.silenced ? trace : null;
    return result;
  }

  @override
  Future<int?> register(HapticPattern pattern) async {
    final id = await _inner.register(pattern);
    if (id != null) _registered[id] = pattern;
    return id;
  }

  @override
  Future<NativeResult> playRegistered(int id) async {
    final pattern = _registered[id];
    if (tier != SimulatedTier.native && pattern != null) {
      // A prepared copy is the full-fidelity one; degrade the long way. A
      // failure is not traced: the handle falls back to `play`, which
      // traces it, so one call is not shown twice.
      return _playDegraded(
        pattern,
        traceFailure: false,
        kind: HapticTraceKind.replay,
      );
    }
    // Passed through untouched: a failure here is how a handle learns its
    // registration was lost and falls back to `play` — which traces itself,
    // so a lost id is not shown twice.
    final result = await _inner.playRegistered(id);
    if (result.played) {
      _emit(kind: HapticTraceKind.replay, played: true, pattern: pattern);
    }
    return result;
  }

  @override
  Future<void> unregister(int id) {
    _registered.remove(id);
    return _inner.unregister(id);
  }

  @override
  Future<void> prepare() => _inner.prepare();

  @override
  Future<void> stop() => _inner.stop();

  // A wrapper must forward this, or a FakeHapticsPlatform underneath stops
  // seeing which intents were performed — and nothing would say so.
  @override
  void noteIntent(HapticIntent intent) {
    _awaitingRecovery = null;
    _inner.noteIntent(intent);
  }

  HapticTrace? _emit({
    required HapticTraceKind kind,
    required bool played,
    String reason = '',
    HapticPattern? pattern,
    SystemHaptic? system,
    SimulatedTier? tier,
    HapticTrace? recoveredFrom,
  }) {
    if (_traces.isClosed) return null;
    final trace = HapticTrace(
      id: _nextId++,
      kind: kind,
      at: DateTime.now(),
      played: played,
      reason: reason,
      pattern: pattern,
      system: system,
      tier: tier ?? this.tier,
      recoveredFrom: recoveredFrom,
    );
    _traces.add(trace);
    return trace;
  }

  /// Closes the trace stream. The app never needs to; tests may.
  Future<void> close() => _traces.close();
}
