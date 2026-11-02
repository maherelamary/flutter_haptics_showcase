import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics/testing.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_theme.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptic_tracer.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptics_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Everything a widget test needs to assert on haptics.
///
/// The fake records every request instead of touching a method channel; the
/// tracer sits on top exactly as it does in the running app.
class HapticsHarness {
  HapticsHarness({FakeHapticsPlatform? fake})
      : fake = fake ?? FakeHapticsPlatform() {
    tracer = TracingHapticsPlatform(this.fake);
  }

  final FakeHapticsPlatform fake;
  late final TracingHapticsPlatform tracer;

  /// Installs the fake and resets the package's global state.
  void install() {
    FlutterHapticsPlatform.instance = tracer;
    FlutterHaptics.enabled = true;
    FlutterHaptics.onFailure = HapticFailureMode.silent;
    FlutterHaptics.onFailureReport = null;
    FlutterHaptics.debugResetSupportCache();
    FlutterHaptics.debugResetFailureLog();
  }

  /// Restores the real platform. Use as `tearDown(harness.uninstall)`.
  void uninstall() {
    FlutterHapticsPlatform.reset();
    FlutterHaptics.enabled = true;
    FlutterHaptics.onFailureReport = null;
    FlutterHaptics.debugResetSupportCache();
    FlutterHaptics.debugResetFailureLog();
    debugDefaultTargetPlatformOverride = null;
  }

  /// Pumps [child] inside the app's theme, a ProviderScope and a Scaffold
  /// host, with a phone-sized surface.
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(390, 844),
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          hapticTracerProvider.overrideWithValue(tracer),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: child,
        ),
      ),
    );
  }
}
