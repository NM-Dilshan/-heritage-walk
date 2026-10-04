import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/heritage_button.dart';
import '../../../shared/widgets/heritage_text_field.dart';
import '../../auth_profile/services/profile_service.dart';
import '../../auth_profile/widgets/profile_avatar.dart';
import '../models/heritage_place.dart';
import '../services/discovery_scope.dart';
import '../services/discovery_service.dart';
import '../widgets/category_chip.dart';
import '../widgets/discovery_layout.dart';
import '../widgets/place_card.dart';
import '../widgets/place_preview_sheet.dart';
import '../widgets/section_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    final state = DiscoveryScope.of(context);
    final discovery = state.discovery;
    final places = discovery.filteredPlaces;
    final filtered =
        discovery.query.trim().isNotEmpty || discovery.category != 'All';
    final featured = filtered
        ? <HeritagePlace>[]
        : places.where((place) => place.isFeatured).toList();
    final explore = filtered
        ? places
        : places.where((place) => !place.isFeatured).toList();
    Widget cards(List<HeritagePlace> places) => PlaceCardGrid(
      places: places,
      isFavorite: state.favorites.isFavorite,
      onFavorite: state.favorites.toggleFavorite,
      onTap: (place) => showPlacePreview(context, place),
    );
    return DiscoveryLayout(
      title: 'HeritageWalk',
      selectedIndex: ModalRoute.of(context)?.settings.name == AppRoutes.explore
          ? 1
          : 0,
      actions: [
        IconButton(
          tooltip: 'My Favorites',
          onPressed: () => Navigator.pushNamed(context, AppRoutes.favorites),
          icon: const Icon(Icons.favorite_border),
        ),
        IconButton(
          tooltip: 'View Profile',
          onPressed: () => Navigator.pushNamed(context, AppRoutes.profile),
          icon: ProfileAvatar(
            profile: ProfileScope.of(context).profile,
            radius: 18,
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Image.asset(
                AppAssets.logo,
                width: 64,
                height: 64,
                semanticLabel: 'HeritageWalk official logo',
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to HeritageWalk',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('Discover the heritage of Sri Lanka'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
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
                    onPressed: () {
                      _search.clear();
                      discovery.setQuery('');
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: DiscoveryService.categories
                  .map(
                    (category) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: CategoryChip(
                        label: category,
                        selected: discovery.category == category,
                        onSelected: () => discovery.setCategory(category),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Your next heritage journey',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose your destination and interests. Make a plan that feels like you.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 20),
                  HeritageButton(
                    label: 'Plan a Tour',
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.planTour),
                  ),
                ],
              ),
            ),
          ),
          if (places.isEmpty)
            const DiscoveryEmptyState(
              title: 'No places found',
              message: 'Try another search or choose a different category.',
              icon: Icons.search_off,
            ),
          if (featured.isNotEmpty) ...[
            const SectionHeader(title: 'Featured Places'),
            cards(featured),
          ],
          if (explore.isNotEmpty) ...[
            SectionHeader(
              title: filtered ? 'Explore Sri Lanka' : 'Popular Heritage Sites',
              subtitle: filtered
                  ? '${places.length} matching places'
                  : 'Find a story worth exploring',
            ),
            cards(explore),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
