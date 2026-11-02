import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/app.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptic_tracer.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptics_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  final prefs = await SharedPreferences.getInstance();

  // Wrap the real platform so the Haptic Island can show every haptic.
  // A client app skips this line; everything else here is the standard setup.
  final tracer = TracingHapticsPlatform(FlutterHapticsPlatform.instance);
  FlutterHapticsPlatform.instance = tracer;

  // Honour the user's switch before anything can play.
  FlutterHaptics.enabled =
      prefs.getBool(HapticsSettingsNotifier.enabledKey) ?? true;

  // Warm the iOS engine so the first tap is not the slow one.
  FlutterHaptics.prepare();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        hapticTracerProvider.overrideWithValue(tracer),
      ],
      child: const TactileApp(),
    ),
  );
}
