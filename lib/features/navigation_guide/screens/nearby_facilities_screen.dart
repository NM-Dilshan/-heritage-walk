import 'package:flutter/material.dart';

import '../../../shared/widgets/heritage_text_field.dart';
import '../../discovery_planning/models/heritage_place.dart';
import '../../discovery_planning/widgets/category_chip.dart';
import '../../discovery_planning/widgets/discovery_layout.dart';
import '../services/facility_service.dart';
import '../services/navigation_guide_scope.dart';
import '../widgets/facility_card.dart';

class NearbyFacilitiesScreen extends StatefulWidget {
  const NearbyFacilitiesScreen({super.key, this.place});
  final HeritagePlace? place;
  @override
  State<NearbyFacilitiesScreen> createState() => _NearbyFacilitiesScreenState();
}

class _NearbyFacilitiesScreenState extends State<NearbyFacilitiesScreen> {
  String _query = '', _filter = 'All';
  @override
  Widget build(BuildContext context) {
    final facilities = NavigationGuideScope.of(context).facilities
        .searchFacilities(_query, filter: _filter);
    return DiscoveryLayout(
      title: 'Nearby Facilities',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Useful places around your destination',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (widget.place != null) ...[
            const SizedBox(height: 8),
            Text(widget.place!.name),
          ],
          const SizedBox(height: 12),
          const Text(
            'Demo facility information. Fictional listings, distances and open/closed status; not verified nearby services.',
          ),
          const SizedBox(height: 24),
          HeritageTextField(
            label: 'Search facilities',
            prefixIcon: const Icon(Icons.search),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: FacilityService.filters
                  .map(
                    (filter) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: CategoryChip(
                        label: filter,
                        selected: _filter == filter,
                        onSelected: () => setState(() => _filter = filter),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),
          if (facilities.isEmpty)
            const DiscoveryEmptyState(
              title: 'No facilities found',
              message: 'Try another search or category.',
              icon: Icons.search_off,
            ),
          for (final facility in facilities)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: FacilityCard(facility: facility),
            ),
          const SizedBox(height: 96),
        ],
      ),
    );
  }
}
