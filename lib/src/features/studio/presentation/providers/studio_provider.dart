import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptics_providers.dart';
import 'package:flutter_haptics_showcase/src/features/studio/domain/studio_draft.dart';
import 'package:flutter_haptics_showcase/src/features/studio/domain/studio_event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The pattern open in the Studio. Saved as it changes and restored on the
/// next launch.
class StudioNotifier extends Notifier<StudioDraft> {
  static const storageKey = 'studio.draft';

  /// Where a saved draft this build cannot read is set aside, so the next
  /// edit does not overwrite the only copy of it.
  static const unreadableKey = 'studio.draft.unreadable';

  /// How long edits settle before the draft is written, so a slider drag
  /// is one save rather than dozens.
  static const saveDelay = Duration(milliseconds: 300);

  late SharedPreferences _prefs;
  int _nextId = 0;
  Timer? _saveTimer;
  StudioDraft? _unsaved;

  int _id() => _nextId++;

  @override
  StudioDraft build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    // Not on the first build: that state was just read from storage (or is
    // the starter), and writing it back straight away would replace an
    // unreadable draft before anyone touched the Studio.
    listenSelf((previous, next) {
      if (previous != null) _scheduleSave(next);
    });
    ref.onDispose(_flush);
    return _restore() ?? _starter();
  }

  StudioDraft? _restore() {
    final saved = _prefs.getString(storageKey);
    if (saved == null) return null;
    try {
      final draft = StudioDraft.fromJson(jsonDecode(saved));
      _nextId = draft.events.fold(0, (next, e) => math.max(next, e.id + 1));
      return draft;
    } on Object {
      // Damaged, or saved by a build with another format: start fresh
      // rather than fail to open the Studio, keeping the old one aside.
      _prefs.setString(unreadableKey, saved);
      return null;
    }
  }

  void _scheduleSave(StudioDraft draft) {
    _unsaved = draft;
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, _flush);
  }

  /// Writes any pending edit now rather than after the debounce.
  ///
  /// For the app going to the background, where the OS may kill it before
  /// the timer fires.
  void flush() => _flush();

  void _flush() {
    _saveTimer?.cancel();
    final draft = _unsaved;
    if (draft == null) return;
    _unsaved = null;
    _prefs.setString(storageKey, jsonEncode(draft.toJson()));
  }

  /// What a first launch opens with.
  StudioDraft _starter() => StudioDraft(
        events: [
          StudioEvent(
            id: _id(),
            kind: StudioEventKind.tap,
            intensity: 0.8,
            sharpness: 0.75,
          ),
          StudioEvent(
            id: _id(),
            kind: StudioEventKind.tap,
            gapMs: 70,
            intensity: 0.5,
            sharpness: 0.4,
          ),
          StudioEvent(
            id: _id(),
            kind: StudioEventKind.rumble,
            gapMs: 60,
            intensity: 0.8,
            sharpness: 0.35,
            durationMs: 280,
            curve: StudioCurve.spike,
          ),
        ],
      );

  /// Appends a new event and returns its id.
  int add(StudioEventKind kind) {
    final id = _id();
    final event = switch (kind) {
      StudioEventKind.tap => StudioEvent(
          id: id,
          kind: kind,
          gapMs: state.events.isEmpty ? 0 : 60,
          sharpness: 0.6,
        ),
      StudioEventKind.rumble => StudioEvent(
          id: id,
          kind: kind,
          gapMs: state.events.isEmpty ? 0 : 60,
          intensity: 0.6,
          sharpness: 0.4,
          curve: StudioCurve.fadeOut,
        ),
    };
    state = state.copyWith(events: [...state.events, event]);
    return id;
  }

  void update(StudioEvent event) => state = state.copyWith(
        events: [
          for (final e in state.events) e.id == event.id ? event : e,
        ],
      );

  void remove(int id) => state = state.copyWith(
        events: [
          for (final e in state.events)
            if (e.id != id) e,
        ],
      );

  /// Inserts a copy right after [id] and returns the copy's id.
  int? duplicate(int id) {
    final index = state.events.indexWhere((e) => e.id == id);
    if (index < 0) return null;
    final copy = state.events[index].copyWith(id: _id(), gapMs: 40);
    state = state.copyWith(
      events: [...state.events]..insert(index + 1, copy),
    );
    return copy.id;
  }

  /// Moves the event at [oldIndex] to [newIndex], where [newIndex] already
  /// accounts for the removal — `onReorderItem` semantics.
  void move(int oldIndex, int newIndex) {
    final events = [...state.events];
    final moved = events.removeAt(oldIndex);
    events.insert(newIndex.clamp(0, events.length), moved);
    state = state.copyWith(events: events);
  }

  void rename(String name) {
    final trimmed = name.trim();
    state = state.copyWith(name: trimmed.isEmpty ? 'Untitled' : trimmed);
  }

  void setLoop(bool loop) => state = state.copyWith(loop: loop);

  void clear() => state = state.copyWith(events: const []);

  /// Replaces the draft with an approximation of [pattern].
  void load(String name, HapticPattern pattern) => state = StudioDraft(
        name: name,
        events: StudioDraft.eventsFromPattern(pattern, _id),
        loop: state.loop,
      );

  /// Puts back a draft taken earlier — for undo.
  void restore(StudioDraft draft) => state = draft;
}

final studioProvider = NotifierProvider<StudioNotifier, StudioDraft>(
  StudioNotifier.new,
);
