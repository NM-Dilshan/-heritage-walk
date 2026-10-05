import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../features/discovery_planning/services/discovery_scope.dart';
import 'heritage_bottom_navigation.dart';

/// Main tabs replace the current stack; detail screens still use normal pushes.
class MainBottomNavigation extends StatelessWidget {
  const MainBottomNavigation({super.key, required this.selectedIndex});
  final int selectedIndex;
  static void openHome(BuildContext context) =>
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
  static void openExplore(
    BuildContext context, {
    String category = 'All',
    String query = '',
  }) {
    final discovery = DiscoveryScope.of(context).discovery;
    discovery.setQuery(query);
    discovery.setCategory(category);
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.explore, (_) => false);
  }

  @override
  Widget build(BuildContext context) => HeritageBottomNavigation(
    selectedIndex: selectedIndex,
    onDestinationSelected: (index) {
      final target = switch (index) {
        0 => AppRoutes.home,
        1 => AppRoutes.explore,
        2 => AppRoutes.map,
        3 => AppRoutes.itineraries,
        _ => AppRoutes.profile,
      };
      if (ModalRoute.of(context)?.settings.name == target) return;
      Navigator.of(context).pushNamedAndRemoveUntil(target, (_) => false);
    },
  );
}
