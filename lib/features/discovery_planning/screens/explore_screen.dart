import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/heritage_text_field.dart';
import '../../admin/services/catalog_controller.dart';
import '../services/discovery_scope.dart';
import '../services/discovery_service.dart';
import '../widgets/category_chip.dart';
import '../widgets/discovery_layout.dart';
import '../widgets/place_card.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _search = TextEditingController();
  bool _initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _search.text = DiscoveryScope.of(context).discovery.query;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = DiscoveryScope.of(context), discovery = state.discovery;
    final places = discovery.filteredPlaces;
    return DiscoveryLayout(
      title: 'Explore Sri Lanka',
      selectedIndex: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HeritageTextField(
            label: 'Search heritage places...',
            hint: 'Name, city, district or category',
            controller: _search,
            onChanged: discovery.setQuery,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: discovery.query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _search.clear();
                      discovery.setQuery('');
                    },
                  ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final category in DiscoveryService.categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: CategoryChip(
                      label: category,
                      selected: discovery.category == category,
                      onSelected: () => discovery.setCategory(category),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
              places.isEmpty)
            DiscoveryEmptyState(
              title: discovery.places.where((p) => p.isActive).isEmpty
                  ? 'No places available'
                  : 'No places found',
              message: discovery.places.where((p) => p.isActive).isEmpty
                  ? 'Active heritage places will appear here when available.'
                  : 'Try another search or choose a different category.',
              icon: Icons.search_off,
            ),
          if (!discovery.catalogLoading && discovery.catalogError == null) ...[
            if (places.isNotEmpty)
              Text(
                '${places.length} places',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            PlaceCardGrid(
              places: places,
              isFavorite: state.favorites.isFavorite,
              onFavorite: state.favorites.toggleFavorite,
              onTap: (place) => Navigator.pushNamed(
                context,
                AppRoutes.placeDetails,
                arguments: place,
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
