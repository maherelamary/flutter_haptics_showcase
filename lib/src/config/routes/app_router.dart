import 'package:flutter/material.dart';
import 'package:flutter_haptics_showcase/src/config/routes/app_shell.dart';
import 'package:flutter_haptics_showcase/src/config/routes/route_paths.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/core/showcase/entry_detail_page.dart';
import 'package:flutter_haptics_showcase/src/features/flows/presentation/pages/chat_flow_page.dart';
import 'package:flutter_haptics_showcase/src/features/flows/presentation/pages/checkout_flow_page.dart';
import 'package:flutter_haptics_showcase/src/features/flows/presentation/pages/flows_page.dart';
import 'package:flutter_haptics_showcase/src/features/flows/presentation/pages/onboarding_flow_page.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/data/gallery_catalog.dart';
import 'package:flutter_haptics_showcase/src/features/gallery/presentation/pages/gallery_page.dart';
import 'package:flutter_haptics_showcase/src/features/home/presentation/pages/home_page.dart';
import 'package:flutter_haptics_showcase/src/features/lab/data/lab_catalog.dart';
import 'package:flutter_haptics_showcase/src/features/lab/presentation/pages/lab_page.dart';
import 'package:flutter_haptics_showcase/src/features/settings/presentation/pages/settings_page.dart';
import 'package:flutter_haptics_showcase/src/features/studio/presentation/pages/studio_page.dart';
import 'package:flutter_haptics_showcase/src/features/system/presentation/pages/system_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: RoutePaths.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.home,
                builder: (context, state) => const HomePage(),
                routes: [
                  GoRoute(
                    path: 'system',
                    builder: (context, state) => const SystemPage(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.gallery,
                builder: (context, state) => const GalleryPage(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final entry =
                          GalleryCatalog.byId(state.pathParameters['id']!);
                      return entry == null
                          ? const _NotFound()
                          : EntryDetailPage(
                              entry: entry,
                              accent: AppColors.gallery,
                            );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.lab,
                builder: (context, state) => const LabPage(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final entry =
                          LabCatalog.byId(state.pathParameters['id']!);
                      return entry == null
                          ? const _NotFound()
                          : EntryDetailPage(
                              entry: entry,
                              accent: AppColors.lab,
                            );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.flows,
                builder: (context, state) => const FlowsPage(),
                routes: [
                  // Flows run full screen, above the tab bar, like the real
                  // journeys they stand in for.
                  GoRoute(
                    path: 'checkout',
                    parentNavigatorKey: _rootKey,
                    builder: (context, state) => const CheckoutFlowPage(),
                  ),
                  GoRoute(
                    path: 'onboarding',
                    parentNavigatorKey: _rootKey,
                    builder: (context, state) => const OnboardingFlowPage(),
                  ),
                  GoRoute(
                    path: 'chat',
                    parentNavigatorKey: _rootKey,
                    builder: (context, state) => const ChatFlowPage(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.studio,
                builder: (context, state) => const StudioPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.settings,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Nothing here.')),
      );
}
