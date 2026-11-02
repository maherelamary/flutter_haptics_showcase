import 'package:flutter/material.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/core/showcase/entry_detail_page.dart';
import 'package:flutter_haptics_showcase/src/core/showcase/showcase_entry.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/data/gallery_catalog.dart';
import 'package:flutter_haptics_showcase/src/features/lab/data/lab_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/haptics_harness.dart';

/// Opens every Gallery and Lab entry on a phone-sized screen.
///
/// Fails on any exception a demo throws while building or settling. Layout
/// overflows are printed rather than failed: the test font's glyphs are wider
/// than real ones, so a tight row can overflow here and not on a phone. Read
/// the printed list as candidates to check on a device.
void main() {
  late HapticsHarness harness;

  setUp(() => harness = HapticsHarness()..install());
  tearDown(() => harness.uninstall());

  Future<void> open(
    WidgetTester tester,
    ShowcaseEntry entry,
    Color accent,
  ) async {
    final overflows = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (details.exception is FlutterError &&
          text.contains('overflowed')) {
        overflows.add(text.split('\n').first);
        return;
      }
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    await harness.pump(tester, EntryDetailPage(entry: entry, accent: accent));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // Tear the page down so timers and tickers are disposed inside the test.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));

    if (overflows.isNotEmpty) {
      debugPrint('⚠ ${entry.id}: ${overflows.toSet().join(' | ')}');
    }
  }

  group('Gallery', () {
    for (final entry in GalleryCatalog.entries) {
      testWidgets(entry.id, (tester) async {
        await open(tester, entry, AppColors.gallery);
      });
    }
  });

  group('Lab', () {
    for (final entry in LabCatalog.entries) {
      testWidgets(entry.id, (tester) async {
        await open(tester, entry, AppColors.lab);
      });
    }
  });

  test('catalog ids are unique and URL-safe', () {
    final ids = [
      ...GalleryCatalog.entries.map((e) => e.id),
      ...LabCatalog.entries.map((e) => e.id),
    ];
    expect(ids.toSet(), hasLength(ids.length));
    for (final id in ids) {
      expect(RegExp(r'^[a-z0-9-]+$').hasMatch(id), isTrue, reason: id);
    }
  });
}
