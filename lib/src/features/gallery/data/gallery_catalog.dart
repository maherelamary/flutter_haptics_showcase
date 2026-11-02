import 'package:flutter_haptics_showcase/src/core/showcase/showcase_entry.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/data/gallery_controls_entries.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/data/gallery_interactions_entries.dart';

/// Every component in the Gallery, in display order.
abstract final class GalleryCatalog {
  /// Category order on the Gallery page.
  static const categories = <String>[
    'Buttons',
    'Selection',
    'Sliders & pickers',
    'Gestures',
    'Input',
    'Feedback',
  ];

  static final List<ShowcaseEntry> entries = [
    ...galleryControlsEntries,
    ...galleryInteractionsEntries,
  ];

  static ShowcaseEntry? byId(String id) {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }
}
