import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/main_bottom_navigation.dart';
import '../../admin/services/catalog_controller.dart';
import '../../auth_profile/services/profile_service.dart';
import '../../auth_profile/widgets/profile_avatar.dart';
import '../models/heritage_place.dart';
import '../services/discovery_scope.dart';
import '../widgets/category_chip.dart';
import '../widgets/discovery_layout.dart';
import '../widgets/place_card.dart';
import '../widgets/section_header.dart';

/// Overview only: selection never depends on Explore's current query/filter.
List<HeritagePlace> featuredPlaces(Iterable<HeritagePlace> catalog) {
  final active = catalog.where((p) => p.isActive).toList()
    ..sort((a, b) {
      if (a.isFeatured != b.isFeatured) return a.isFeatured ? -1 : 1;
      final byName = a.name.compareTo(b.name);
      return byName == 0 ? a.id.compareTo(b.id) : byName;
    });
  return active.take(4).toList();
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = DiscoveryScope.of(context), discovery = state.discovery;
    final featured = featuredPlaces(discovery.places);
    final categories =
        discovery.places
            .where((p) => p.isActive)
            .map((p) => p.category)
            .toSet()
            .toList()
          ..sort();
    Widget action(String label, IconData icon, String route) =>
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(context, route),
          icon: Icon(icon),
          label: Text(label),
        );
    return DiscoveryLayout(
      title: 'HeritageWalk',
      selectedIndex: 0,
      actions: [
        IconButton(
          tooltip: 'My Favorites',
          icon: const Icon(Icons.favorite_border),
          onPressed: () => Navigator.pushNamed(context, AppRoutes.favorites),
        ),
        IconButton(
          tooltip: 'View Profile',
          icon: ProfileAvatar(
            profile: ProfileScope.of(context).profile,
            radius: 18,
          ),
          onPressed: () => Navigator.pushNamed(context, AppRoutes.profile),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Image.asset(
                AppAssets.logo,
                width: 56,
                height: 56,
                semanticLabel: 'HeritageWalk official logo',
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Explore Sri Lanka',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Text('Welcome to HeritageWalk'),
                    const Text(
                      'Discover heritage, save places and plan your next journey.',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Quick Actions'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => MainBottomNavigation.openExplore(context),
                icon: const Icon(Icons.explore_outlined),
                label: const Text('Explore All Places'),
              ),
              action('Plan a Tour', Icons.route_outlined, AppRoutes.planTour),
              action(
                'My Favorites',
                Icons.favorite_border,
                AppRoutes.favorites,
              ),
              action(
                'My Itineraries',
                Icons.event_note_outlined,
                AppRoutes.itineraries,
              ),
              action(
                'Group Tours',
                Icons.groups_outlined,
                AppRoutes.groupTours,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${state.favorites.getFavorites().length} saved places ? ${state.itineraries.savedItineraries.length} saved itineraries',
          ),
          if (categories.isNotEmpty) ...[
            const SectionHeader(title: 'Explore by Category'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in categories)
                  CategoryChip(
                    label: category,
                    selected: false,
                    onSelected: () => MainBottomNavigation.openExplore(
                      context,
                      category: category,
                    ),
                  ),
              ],
            ),
          ],
          const SectionHeader(
            title: 'Featured Places',
            subtitle: 'A few heritage places for your next journey',
          ),
          if (discovery.catalogLoading)
            const Center(child: CircularProgressIndicator()),
          if (discovery.catalogError != null) ...[
            Text(discovery.catalogError!),
            TextButton(
              onPressed: CatalogScope.of(context).retryCatalog,
              child: const Text('Reload places'),
            ),
          ],
          if (!discovery.catalogLoading &&
              discovery.catalogError == null &&
              featured.isEmpty)
            const Text(
              'No active places yet. Explore will show the catalog when it is available.',
            ),
          if (!discovery.catalogLoading && discovery.catalogError == null)
            PlaceCardGrid(
              places: featured,
              isFavorite: state.favorites.isFavorite,
              onFavorite: state.favorites.toggleFavorite,
              onTap: (place) => Navigator.pushNamed(
                context,
                AppRoutes.placeDetails,
                arguments: place,
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
