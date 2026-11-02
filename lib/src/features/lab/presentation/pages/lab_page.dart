import 'package:flutter/material.dart';
import 'package:flutter_haptics_showcase/src/config/routes/route_paths.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/core/showcase/catalog_page.dart';
import 'package:flutter_haptics_showcase/src/features/lab/data/lab_catalog.dart';
import 'package:go_router/go_router.dart';

class LabPage extends StatelessWidget {
  const LabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CatalogPage(
      eyebrow: 'Lab',
      title: 'Experiments',
      intro:
          'Haptics as a material: textures, physics, dials and rhythms — '
          'the things you can only show by touch.',
      entries: LabCatalog.entries,
      categories: LabCatalog.categories,
      accent: AppColors.lab,
      onOpen: (entry) => context.go(RoutePaths.labEntry(entry.id)),
    );
  }
}
