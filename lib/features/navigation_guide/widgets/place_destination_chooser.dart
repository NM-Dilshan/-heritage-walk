import 'package:flutter/material.dart';

import '../../discovery_planning/services/discovery_scope.dart';
import '../../discovery_planning/widgets/discovery_layout.dart';

/// Safe fallback for missing/wrong place arguments on information routes.
class PlaceDestinationChooser extends StatelessWidget {
  const PlaceDestinationChooser({
    super.key,
    required this.title,
    required this.routeName,
  });
  final String title, routeName;
  @override
  Widget build(BuildContext context) => DiscoveryLayout(
    title: title,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Choose a destination',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        for (final place in DiscoveryScope.of(context).discovery.places)
          ListTile(
            title: Text(place.name),
            subtitle: Text(place.city),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushReplacementNamed(
              context,
              routeName,
              arguments: place,
            ),
          ),
      ],
    ),
  );
}
