import 'package:flutter/material.dart';

import '../../../shared/widgets/main_bottom_navigation.dart';
import '../services/discovery_scope.dart';
import '../widgets/discovery_layout.dart';
import '../widgets/place_card.dart';
import '../widgets/place_preview_sheet.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final service = DiscoveryScope.of(context).favorites;
    final places = service.getFavorites();
    return DiscoveryLayout(
      title: 'My Favorites',
      selectedIndex: 1,
      child: places.isEmpty
          ? DiscoveryEmptyState(
              title: 'No favorites yet',
              message: 'Save places you love and find them here.',
              icon: Icons.favorite_border,
              buttonLabel: 'Explore Places',
              onPressed: () => MainBottomNavigation.openHome(context),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${places.length} places to return to',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                PlaceCardGrid(
                  places: places,
                  isFavorite: service.isFavorite,
                  onFavorite: (place) {
                    service.removeFavorite(place.id);
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${place.name} removed'),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () => service.addFavorite(place),
                        ),
                      ),
                    );
                  },
                  onTap: (place) => showPlacePreview(context, place),
                ),
              ],
            ),
    );
  }
}
