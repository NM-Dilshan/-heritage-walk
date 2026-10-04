import 'package:flutter/material.dart';

import '../../../shared/widgets/heritage_button.dart';
import '../models/heritage_place.dart';
import '../services/discovery_scope.dart';
import 'place_card.dart';

Future<void> showPlacePreview(BuildContext context, HeritagePlace place) {
  final favorites = DiscoveryScope.of(context).favorites;
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
            animation: favorites,
            builder: (_, child) => Column(
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
                Text(
                  'Rating ${place.rating} / 5 · ${place.reviewCount} demo reviews',
                ),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Detailed heritage guide will be connected in Part 4.',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
