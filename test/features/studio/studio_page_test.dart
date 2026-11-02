import 'package:flutter_haptics_showcase/src/core/haptics/fidelity_simulator.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/haptics_providers.dart';
import 'package:flutter_haptics_showcase/src/features/studio/presentation/pages/studio_page.dart';
import 'package:flutter_haptics_showcase/src/features/studio/presentation/providers/studio_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/haptics_harness.dart';

void main() {
  late HapticsHarness harness;

  setUp(() => harness = HapticsHarness()..install());
  tearDown(() => harness.uninstall());

  testWidgets('previews play at the Studio tier, not on top of the '
      'app-wide one', (tester) async {
    await harness.pump(tester, const StudioPage());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(StudioPage)),
    );
    await container
        .read(hapticsSettingsProvider.notifier)
        .setTier(SimulatedTier.rhythm);
    await tester.pump();
    final draft = container.read(studioProvider).toPattern();

    expect(find.textContaining('Studio previews ignore it'), findsOneWidget);

    await tester.tap(find.text('Play'));
    await tester.pump();
    expect(harness.fake.lastPlayed, draft, reason: 'native, not rhythm');
    await tester.pump(const Duration(seconds: 1));

    await tester.ensureVisible(find.text('Intensity'));
    await tester.tap(find.text('Intensity'));
    await tester.pump();
    await tester.ensureVisible(find.text('Play'));
    await tester.tap(find.text('Play'));
    await tester.pump();
    expect(
      harness.fake.lastPlayed,
      FidelitySimulator.degrade(draft, SimulatedTier.intensity),
    );
    await tester.pump(const Duration(seconds: 1));
  });
}
