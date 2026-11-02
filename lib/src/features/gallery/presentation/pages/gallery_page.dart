import 'package:flutter/material.dart';
import 'package:flutter_haptics_showcase/src/config/routes/route_paths.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/core/showcase/catalog_page.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/data/gallery_catalog.dart';
import 'package:go_router/go_router.dart';

class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CatalogPage(
      eyebrow: 'Gallery',
      title: 'Components',
      intro: 'The everyday controls of a client app, each wired the way it '
          'should feel — with the reasoning and the code.',
      entries: GalleryCatalog.entries,
      categories: GalleryCatalog.categories,
      accent: AppColors.gallery,
      onOpen: (entry) => context.go(RoutePaths.galleryEntry(entry.id)),
    );
  }
}
