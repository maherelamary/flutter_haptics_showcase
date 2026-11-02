import 'package:flutter/material.dart';
import 'package:flutter_haptics_showcase/src/config/routes/app_router.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_theme.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptics_providers.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/haptic_island.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TactileApp extends ConsumerWidget {
  const TactileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the settings notifier alive from the first frame, so the user's
    // haptics switch is mirrored into FlutterHaptics.enabled app-wide.
    ref.watch(hapticsSettingsProvider);
    // Starts recording haptics for the flow recaps — listened, not watched,
    // so a new haptic never rebuilds the whole app.
    ref.listen(hapticLogProvider, (_, _) {});

    return MaterialApp.router(
      title: 'Flutter Haptics Tactile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) =>
          HapticIsland(child: child ?? const SizedBox.shrink()),
    );
  }
}
