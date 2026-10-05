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
            route.destination.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text('${route.destination.city}, ${route.destination.district}'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              Text('Demo distance: ${route.distanceKm} km'),
              Text('Demo time: ${route.minutes} min'),
              Text(
                'Mode: ${route.mode == TravelMode.walking ? 'Walking' : 'Driving'}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Illustrative estimates, not a calculated route.'),
        ],
      ),
    ),
  );
}
