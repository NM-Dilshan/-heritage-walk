import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import 'heritage_bottom_navigation.dart';

/// Main tabs replace the current stack; detail screens still use normal pushes.
class MainBottomNavigation extends StatelessWidget {
  const MainBottomNavigation({super.key, required this.selectedIndex});
  final int selectedIndex;
  static void openHome(BuildContext context) =>
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
  @override
  Widget build(BuildContext context) => HeritageBottomNavigation(
    selectedIndex: selectedIndex,
    onDestinationSelected: (index) {
      if (index == 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Map & Navigation will be connected in Part 4.'),
          ),
        );
        return;
      }
      final target = switch (index) {
        0 => AppRoutes.home,
        1 => AppRoutes.explore,
        3 => AppRoutes.itineraries,
        _ => AppRoutes.profile,
      };
      if (ModalRoute.of(context)?.settings.name == target) return;
      Navigator.of(context).pushNamedAndRemoveUntil(target, (_) => false);
    },
  );
}
