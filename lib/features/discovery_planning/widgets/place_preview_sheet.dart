import '../../reviews/widgets/review_widgets.dart';

import 'package:flutter/material.dart';

import '../../../shared/widgets/heritage_button.dart';
import '../../../core/routes/app_routes.dart';
import '../models/heritage_place.dart';
import '../services/discovery_scope.dart';
import 'place_card.dart';

Future<void> showPlacePreview(
  BuildContext context,
  HeritagePlace originalPlace,
) {
  final state = DiscoveryScope.of(context);
  final favorites = state.favorites;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: AnimatedBuilder(
            animation: state,
            builder: (_, child) {
              final place =
                  state.discovery.places
                      .where((p) => p.id == originalPlace.id)
                      .firstOrNull ??
                  favorites
                      .getFavorites()
                      .where((p) => p.id == originalPlace.id)
                      .firstOrNull ??
                  originalPlace;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: PlaceImage(place: place),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    place.name,
                    style: Theme.of(sheetContext).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text('${place.city}, ${place.district}'),
                  const SizedBox(height: 12),
                  Text(place.shortDescription),
                  const SizedBox(height: 12),
                  RatingSummary(placeId: place.id),
                  const SizedBox(height: 20),
                  HeritageButton(
                    label: favorites.isFavorite(place.id)
                        ? 'Remove Favorite'
                        : 'Add Favorite',
                    variant: HeritageButtonVariant.outlined,
                    onPressed: () => favorites.toggleFavorite(place),
                  ),
                  const SizedBox(height: 12),
                  HeritageButton(
                    label: 'View Full Details',
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      Navigator.pushNamed(
                        context,
                        AppRoutes.placeDetails,
                        arguments: place,
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
