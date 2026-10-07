import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../models/facility.dart';

class FacilityCard extends StatelessWidget {
  const FacilityCard({
    super.key,
    required this.facility,
    required this.onMap,
    required this.onNavigate,
  });
  final NearbyFacility facility;
  final VoidCallback onMap, onNavigate;
  static IconData icon(FacilityCategory category) => switch (category) {
    FacilityCategory.hospital => Icons.local_hospital_outlined,
    FacilityCategory.pharmacy => Icons.local_pharmacy_outlined,
    FacilityCategory.police => Icons.local_police_outlined,
    FacilityCategory.atm => Icons.atm,
    FacilityCategory.food => Icons.restaurant,
    FacilityCategory.toilet => Icons.wc,
    FacilityCategory.fuel => Icons.local_gas_station_outlined,
    FacilityCategory.parking => Icons.local_parking,
  };
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.maybeOf(context);
    final distance = facility.distanceMeters < 1000
        ? facility.distanceMeters.round()
        : facility.distanceMeters / 1000;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon(facility.category)),
                const SizedBox(width: 12),
                Expanded(
                  child: facility.name == null
                      ? UiText(
                          'Unnamed facility',
                          style: Theme.of(context).textTheme.titleMedium,
                        )
                      : Text(
                          facility.name!,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            UiText(facility.category.label),
            UiText(
              facility.distanceMeters < 1000
                  ? 'Approx. {0} m away (direct)'
                  : 'Approx. {0} km away (direct)',
              args: [
                l?.number(
                      distance,
                      decimals: facility.distanceMeters < 1000 ? 0 : 1,
                    ) ??
                    distance.toString(),
              ],
            ),
            const SizedBox(height: 8),
            if (facility.address == null)
              const UiText('Address unavailable')
            else
              Text(facility.address!),
            if (facility.openingHours != null) ...[
              const SizedBox(height: 8),
              UiText('OSM opening hours: {0}', args: [facility.openingHours]),
            ],
            if (facility.phone != null) ...[
              const SizedBox(height: 8),
              UiText('OSM phone (unverified): {0}', args: [facility.phone]),
            ],
            if (facility.website != null) ...[
              const SizedBox(height: 8),
              Text(facility.website!),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: onMap,
                  icon: const Icon(Icons.map_outlined),
                  label: const UiText('View on Map'),
                ),
                TextButton.icon(
                  onPressed: onNavigate,
                  icon: const Icon(Icons.directions_outlined),
                  label: const UiText('Navigate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
