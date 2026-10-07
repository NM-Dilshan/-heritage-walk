import '../../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../models/itinerary.dart';
import 'discovery_layout.dart';

class ItineraryCard extends StatelessWidget {
  const ItineraryCard({
    super.key,
    required this.itinerary,
    required this.onView,
    required this.onRename,
    required this.onDelete,
  });
  final Itinerary itinerary;
  final VoidCallback onView, onRename, onDelete;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.route_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  itinerary.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('${itinerary.destination} · ${formatTourDate(itinerary.date)}'),
          const SizedBox(height: 6),
          UiText(
            "{0} · {1} stops",
            args: [
              AppLocalizations.text(context, itinerary.duration),
              itinerary.places.length,
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: onView,
                icon: const Icon(Icons.visibility_outlined),
                label: const UiText('View'),
              ),
              TextButton.icon(
                onPressed: onRename,
                icon: const Icon(Icons.edit_outlined),
                label: const UiText('Rename'),
              ),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                label: const UiText('Delete'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
