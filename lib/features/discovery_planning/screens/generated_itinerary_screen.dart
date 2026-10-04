import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/heritage_button.dart';
import '../services/discovery_scope.dart';
import '../widgets/discovery_layout.dart';
import '../widgets/section_header.dart';

class GeneratedItineraryScreen extends StatelessWidget {
  const GeneratedItineraryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final service = DiscoveryScope.of(context).itineraries;
    final id = ModalRoute.of(context)?.settings.arguments as String?;
    final itinerary = id == null ? null : service.find(id);
    if (itinerary == null) {
      return DiscoveryLayout(
        title: 'Your Itinerary',
        child: DiscoveryEmptyState(
          title: 'Itinerary unavailable',
          message: 'Create a new plan to start your journey.',
          icon: Icons.route_outlined,
          buttonLabel: 'Plan a Tour',
          onPressed: () =>
              Navigator.pushReplacementNamed(context, AppRoutes.planTour),
        ),
      );
    }
    return DiscoveryLayout(
      title: 'Your Itinerary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    itinerary.title,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${itinerary.destination} · ${formatTourDate(itinerary.date)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('${itinerary.duration} · ${itinerary.travelStyle}'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: itinerary.interests
                        .map((interest) => Chip(label: Text(interest)))
                        .toList(),
                  ),
                  if (itinerary.isSaved)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline),
                          SizedBox(width: 8),
                          Expanded(child: Text('Saved itinerary')),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SectionHeader(
            title: 'Suggested stops',
            subtitle: 'A starting point for your visit, not a complete travel schedule.',
          ),
          const Text(
            'Visit estimates are illustrative. Travel times and opening hours are not checked. The small local catalogue may have only one stop for your destination.',
          ),
          const SizedBox(height: 20),
          for (var index = 0; index < itinerary.places.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(radius: 20, child: Text('${index + 1}')),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Stop ${index + 1}',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              itinerary.places[index].name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${itinerary.places[index].city}, ${itinerary.places[index].district}',
                            ),
                            const SizedBox(height: 8),
                            Text(itinerary.places[index].shortDescription),
                            const SizedBox(height: 10),
                            Text(
                              itinerary.places[index].category == 'Architecture'
                                  ? 'Approx. 1 hour'
                                  : 'Approx. 2 hours',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          HeritageButton(
            label: itinerary.isSaved ? 'Itinerary Saved' : 'Save Itinerary',
            enabled: !itinerary.isSaved,
            onPressed: () {
              if (service.save(itinerary.id)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Itinerary saved successfully')),
                );
              }
            },
          ),
          const SizedBox(height: 12),
          HeritageButton(
            label: 'Regenerate',
            variant: HeritageButtonVariant.outlined,
            onPressed: () {
              try {
                final regenerated = service.generate(
                  itinerary.plan,
                  previous: itinerary,
                );
                Navigator.pushReplacementNamed(
                  context,
                  AppRoutes.generatedItinerary,
                  arguments: regenerated.id,
                );
                if (regenerated.places.map((place) => place.id).join(',') ==
                    itinerary.places.map((place) => place.id).join(',')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'These are the available local stops for your selections. Try another destination or travel style for more variety.',
                      ),
                    ),
                  );
                }
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Edit your plan and choose a future date to regenerate.',
                    ),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 12),
          HeritageButton(
            label: 'Edit Plan',
            variant: HeritageButtonVariant.outlined,
            onPressed: () => Navigator.pushReplacementNamed(
              context,
              AppRoutes.planTour,
              arguments: itinerary.plan,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.itineraries,
              (_) => false,
            ),
            icon: const Icon(Icons.bookmarks_outlined),
            label: const Text('My Itineraries'),
          ),
          const SizedBox(height: 112),
        ],
      ),
    );
  }
}
