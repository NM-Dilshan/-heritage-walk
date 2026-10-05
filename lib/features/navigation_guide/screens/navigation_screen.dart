import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/heritage_button.dart';
import '../../discovery_planning/models/heritage_place.dart';
import '../../discovery_planning/services/discovery_scope.dart';
import '../../discovery_planning/widgets/discovery_layout.dart';
import '../../discovery_planning/widgets/section_header.dart';
import '../models/route_info.dart';
import '../services/navigation_guide_scope.dart';
import '../widgets/map_placeholder.dart';
import '../widgets/route_summary_card.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key, this.place});
  final HeritagePlace? place;
  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  bool _initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final place = widget.place;
    final service = NavigationGuideScope.of(context).navigation;
    if (place != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) service.selectDestination(place);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = NavigationGuideScope.of(context).navigation;
    final places = DiscoveryScope.of(context).discovery.places;
    final route = service.route;
    return DiscoveryLayout(
      title: 'Navigation',
      selectedIndex: 2,
      actions: [
        IconButton(
          tooltip: 'Emergency Support',
          onPressed: () => Navigator.pushNamed(context, AppRoutes.emergency),
          icon: const Icon(Icons.health_and_safety_outlined),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choose a destination',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey(
              '${service.destination?.id}:${places.map((p) => p.id).join(',')}',
            ),
            initialValue:
                places.any((place) => place.id == service.destination?.id)
                ? service.destination?.id
                : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Destination'),
            items: places
                .map(
                  (place) => DropdownMenuItem(
                    value: place.id,
                    child: Text(
                      place.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (id) {
              if (id != null) {
                service.selectDestination(
                  places.firstWhere((place) => place.id == id),
                );
              }
            },
          ),
          const SizedBox(height: 24),
          if (route == null)
            const DiscoveryEmptyState(
              title: 'Your next journey starts here',
              message: 'Select a heritage place to see a demo route.',
              icon: Icons.map_outlined,
            ),
          if (route != null) ...[
            MapPlaceholder(destination: route.destination.name),
            const SizedBox(height: 20),
            RouteSummaryCard(route: route),
            const SectionHeader(title: 'Travel mode'),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: TravelMode.values
                  .map(
                    (mode) => ChoiceChip(
                      label: Text(
                        mode == TravelMode.walking ? 'Walking' : 'Driving',
                      ),
                      selected: service.mode == mode,
                      showCheckmark: true,
                      onSelected: (_) => service.selectMode(mode),
                    ),
                  )
                  .toList(),
            ),
            const SectionHeader(title: 'Demo directions'),
            for (var index = 0; index < RouteInfo.directions.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('${index + 1}. ${RouteInfo.directions[index]}'),
              ),
            const SizedBox(height: 16),
            if (service.isActive) ...[
              Text(
                'Demo navigation active',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              HeritageButton(
                label: 'End Navigation',
                variant: HeritageButtonVariant.outlined,
                onPressed: service.end,
              ),
            ] else
              HeritageButton(
                label: 'Start Demo Navigation',
                onPressed: () {
                  if (service.start()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Demo navigation started')),
                    );
                  }
                },
              ),
            const SizedBox(height: 120),
          ],
        ],
      ),
    );
  }
}
