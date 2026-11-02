import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/controls/switch_demo.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/demos/interactions/async_save_demo.dart';
import 'package:flutter_haptics_showcase/src/features/lab/presentation/demos/metronome_demo.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/haptics_harness.dart';

/// The testing recipe the skill teaches: install a fake platform, drive the
/// widget, assert on the haptics like any other behaviour.
void main() {
  final android = TargetPlatformVariant.only(TargetPlatform.android);
  late HapticsHarness harness;

  setUp(() => harness = HapticsHarness()..install());
  tearDown(() => harness.uninstall());

  testWidgets('switches feel different on and off', (tester) async {
    await harness.pump(tester, const Scaffold(body: SwitchDemo()));

    // Row 2 ("Location") starts off.
    await tester.tap(find.byType(Switch).at(1));
    await tester.pump();
    await tester.tap(find.byType(Switch).at(1));
    await tester.pump();

    expect(harness.fake.systemHaptics, [
      AndroidHaptic.toggleOn,
      AndroidHaptic.toggleOff,
    ]);
  }, variant: android);

  testWidgets('async save: success and failure come from ref.listen',
      (tester) async {
    await harness.pump(
      tester,
      const Scaffold(body: Center(child: AsyncSaveDemo())),
    );

    await tester.tap(find.text('Save changes'));
    await tester.pump(); // loading
    await tester.pump(const Duration(seconds: 1)); // done

    expect(harness.fake.systemHaptics, [
      AndroidHaptic.contextClick, // the press
      AndroidHaptic.confirm, // the outcome
    ]);

    harness.fake.clear();
    await tester.tap(find.byType(Switch)); // simulate failure
    await tester.pump();
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500)); // shake settles

    expect(harness.fake.systemHaptics, [
      AndroidHaptic.toggleOn,
      AndroidHaptic.contextClick,
      AndroidHaptic.reject,
    ]);
  }, variant: android);

  testWidgets('metronome stops when the app is hidden', (tester) async {
    addTearDown(
      () => tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed),
    );
    await harness.pump(tester, const Scaffold(body: MetronomeDemo()));
    int beats() => harness.fake.replays.length + harness.fake.played.length;

    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(seconds: 2)); // 96 BPM: a few beats
    expect(beats(), greaterThan(0));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    final felt = beats();

    await tester.pump(const Duration(seconds: 2));
    expect(beats(), felt, reason: 'no beats while hidden');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 2));
    expect(beats(), felt, reason: 'resuming waits for Start');
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('metronome keeps time while only inactive', (tester) async {
    addTearDown(
      () => tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed),
    );
    await harness.pump(tester, const Scaffold(body: MetronomeDemo()));
    int beats() => harness.fake.replays.length + harness.fake.played.length;

    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(seconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    final felt = beats();

    await tester.pump(const Duration(seconds: 2));
    expect(beats(), greaterThan(felt));
    expect(find.text('Stop'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    await tester.pump();
  });
}
