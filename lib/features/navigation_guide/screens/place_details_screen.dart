import '../../reviews/widgets/review_widgets.dart';

import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/heritage_button.dart';
import '../../discovery_planning/models/heritage_place.dart';
import '../../discovery_planning/services/discovery_scope.dart';
import '../../discovery_planning/widgets/discovery_layout.dart';
import '../../discovery_planning/widgets/place_card.dart';
import '../../discovery_planning/widgets/section_header.dart';
import '../models/guide_content.dart';

class PlaceDetailsScreen extends StatefulWidget {
  const PlaceDetailsScreen({
    super.key,
    required this.place,
    this.adminPreview = false,
  });
  final HeritagePlace place;
  final bool adminPreview;
  @override
  State<PlaceDetailsScreen> createState() => _PlaceDetailsScreenState();
}

class _PlaceDetailsScreenState extends State<PlaceDetailsScreen> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final state = DiscoveryScope.of(context);
    final place = widget.adminPreview
        ? widget.place
        : state.discovery.places
                  .where((p) => p.id == widget.place.id)
                  .firstOrNull ??
              widget.place;
    final favorites = DiscoveryScope.of(context).favorites;
    final content = GuideContent.forPlace(place);
    return DiscoveryLayout(
      title: 'Place Details',
      actions: [
        IconButton(
          tooltip: favorites.isFavorite(place.id)
              ? 'Remove Favorite'
              : 'Add Favorite',
          icon: Icon(
            favorites.isFavorite(place.id)
                ? Icons.favorite
                : Icons.favorite_border,
          ),
          onPressed: () => favorites.toggleFavorite(place),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: PlaceImage(place: place),
          ),
          const SizedBox(height: 24),
          Text(
            place.name,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '${place.city}, ${place.district}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          RatingSummary(placeId: place.id),
          const SectionHeader(
            title: 'Quick information',
            subtitle: 'Demo information - confirm current hours and fees before visiting.',
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _info(
                    context,
                    'Opening Hours',
                    place.openingHours ?? 'Not verified',
                  ),
                  _info(
                    context,
                    'Entrance Fee',
                    place.entranceFee ?? 'Not verified',
                  ),
                  _info(
                    context,
                    'Recommended Visit Duration',
                    'Approx. 2 hours (demo)',
                  ),
                  _info(context, 'Category', place.category),
                  if (widget.adminPreview) ...[
                    _info(
                      context,
                      'Status',
                      place.isActive ? 'Active' : 'Inactive',
                    ),
                    _info(context, 'Short description', place.shortDescription),
                    _info(context, 'Image reference', place.imagePath),
                    _info(context, 'Created by', place.createdBy),
                    _info(context, 'Updated by', place.updatedBy),
                    if (place.createdAt != null)
                      _info(
                        context,
                        'Created',
                        place.createdAt!.toLocal().toString(),
                      ),
                    if (place.updatedAt != null)
                      _info(
                        context,
                        'Updated',
                        place.updatedAt!.toLocal().toString(),
                      ),
                  ],
                  if (place.address.isNotEmpty)
                    _info(context, 'Address', place.address),
                  if (place.historicalPeriod.isNotEmpty)
                    _info(context, 'Historical period', place.historicalPeriod),
                  if (place.accessibilityInfo.isNotEmpty)
                    _info(context, 'Accessibility', place.accessibilityInfo),
                  if (place.latitude != null && place.longitude != null)
                    _info(
                      context,
                      'Coordinates',
                      '${place.latitude}, ${place.longitude}',
                    ),
                ],
              ),
            ),
          ),
          const SectionHeader(title: 'About this place'),
          Text(
            place.description,
            maxLines: _expanded ? null : 4,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
          if (place.description.length > 200)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Show less' : 'Read more'),
              ),
            ),
          const SectionHeader(title: 'Highlights'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                (place.highlights.isEmpty
                        ? content.highlights
                        : place.highlights)
                    .map((highlight) => Chip(label: Text(highlight)))
                    .toList(),
          ),
          const SectionHeader(title: 'Visitor Tips'),
          for (final tip in GuideContent.visitorTips)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('- $tip'),
            ),
          const SizedBox(height: 16),
          HeritageButton(
            label: 'Start Navigation',
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.navigation,
              arguments: place,
            ),
          ),
          const SizedBox(height: 12),
          HeritageButton(
            label: 'Digital Guide',
            variant: HeritageButtonVariant.outlined,
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.digitalGuide,
              arguments: place,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            icon: const Icon(Icons.local_convenience_store_outlined),
            label: const Text('Nearby Facilities'),
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.facilities,
              arguments: place,
            ),
          ),
          ReviewSection(placeId: place.id),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _info(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(value),
      ],
    ),
  );
}
