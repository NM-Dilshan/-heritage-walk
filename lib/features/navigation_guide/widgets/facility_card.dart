import 'package:flutter/material.dart';

import '../models/facility.dart';

class FacilityCard extends StatelessWidget {
  const FacilityCard({super.key, required this.facility});
  final Facility facility;
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
              Icon(switch (facility.type) {
                FacilityType.restaurant => Icons.restaurant,
                FacilityType.cafe => Icons.local_cafe_outlined,
                FacilityType.restroom => Icons.wc,
                FacilityType.parking => Icons.local_parking,
                FacilityType.hospital => Icons.local_hospital_outlined,
                FacilityType.atm => Icons.atm,
                FacilityType.police => Icons.local_police_outlined,
                FacilityType.information => Icons.info_outline,
              }),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  facility.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(facility.type.name),
              Text('${facility.distanceKm} km (demo)'),
              Text(facility.isOpen ? 'Open (demo)' : 'Closed (demo)'),
            ],
          ),
          const SizedBox(height: 8),
          Text(facility.description),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.directions_outlined),
              label: const Text('Directions'),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Live facility directions will be available after map integration.',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
