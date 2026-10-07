import '../../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../models/route_info.dart';

class RouteSummaryCard extends StatelessWidget {
  const RouteSummaryCard({super.key, required this.route});
  final RouteInfo route;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            route.destination.hasName
                ? route.destination.name
                : AppLocalizations.text(context, route.destination.name),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (route.destination.subtitle.isNotEmpty)
            Text(route.destination.subtitle),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              UiText("Distance: {0} km", args: [route.distanceKm]),
              UiText("Estimated time: {0} min", args: [route.minutes]),
              UiText(
                "Mode: {0}",
                args: [
                  AppLocalizations.text(
                    context,
                    route.mode == TravelMode.walking ? 'Walking' : 'Driving',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const UiText(
            'Initial route distance and estimated time from OSRM. Recalculate after moving; these are not live remaining estimates.',
          ),
        ],
      ),
    ),
  );
}
