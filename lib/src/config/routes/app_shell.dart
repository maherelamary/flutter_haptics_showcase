import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:go_router/go_router.dart';

/// The tab scaffold around the five pillars.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _select(int index) {
    final current = navigationShell.currentIndex;
    // A tab bar is a segmented control: changing it ticks. Re-tapping the
    // current tab only pops to its root, which is navigation, not a choice.
    if (index != current) FlutterHaptics.perform(AppHaptics.tick);
    navigationShell.goBranch(index, initialLocation: index == current);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _select,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.blur_on_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.widgets_outlined),
            selectedIcon: Icon(Icons.widgets_rounded),
            label: 'Gallery',
          ),
          NavigationDestination(
            icon: Icon(Icons.science_outlined),
            selectedIcon: Icon(Icons.science_rounded),
            label: 'Lab',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route_rounded),
            label: 'Flows',
          ),
          NavigationDestination(
            icon: Icon(Icons.graphic_eq_rounded),
            label: 'Studio',
          ),
        ],
      ),
    );
  }
}
