import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../models/heritage_place.dart';

class PlaceImage extends StatelessWidget {
  const PlaceImage({super.key, required this.place});
  final HeritagePlace place;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      AspectRatio(
        aspectRatio: 16 / 8,
        child: Image.asset(
          place.imagePath,
          fit: BoxFit.cover,
          semanticLabel: place.imagePath == AppAssets.placePlaceholder
              ? 'Placeholder illustration; not a photo of ${place.name}'
              : place.name,
          errorBuilder: (_, error, stack) =>
              const Center(child: Icon(Icons.image_outlined, size: 48)),
        ),
      ),
      if (place.imagePath == AppAssets.placePlaceholder)
        Positioned(
          left: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Placeholder image'),
          ),
        ),
    ],
  );
}

class PlaceCard extends StatelessWidget {
  const PlaceCard({
    super.key,
    required this.place,
    required this.isFavorite,
    required this.onFavorite,
    required this.onTap,
  });
  final HeritagePlace place;
  final bool isFavorite;
  final VoidCallback onFavorite, onTap;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PlaceImage(place: place),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${place.city} · ${place.district}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      place.category,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
          child: Row(
            children: [
              const Icon(Icons.star_rounded, size: 20),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${place.rating} · ${place.reviewCount} demo reviews',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              IconButton(
                tooltip:
                    '${isFavorite ? 'Remove' : 'Save'} ${place.name} ${isFavorite ? 'from' : 'to'} favorites',
                onPressed: onFavorite,
                isSelected: isFavorite,
                icon: const Icon(Icons.favorite_border),
                selectedIcon: Icon(
                  Icons.favorite,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class PlaceCardGrid extends StatelessWidget {
  const PlaceCardGrid({
    super.key,
    required this.places,
    required this.isFavorite,
    required this.onFavorite,
    required this.onTap,
  });
  final List<HeritagePlace> places;
  final bool Function(String) isFavorite;
  final void Function(HeritagePlace) onFavorite, onTap;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 840
          ? 3
          : constraints.maxWidth >= 580
          ? 2
          : 1;
      final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: places
            .map(
              (place) => SizedBox(
                width: width,
                child: PlaceCard(
                  key: ValueKey('place-${place.id}'),
                  place: place,
                  isFavorite: isFavorite(place.id),
                  onFavorite: () => onFavorite(place),
                  onTap: () => onTap(place),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}
