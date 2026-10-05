import 'package:flutter/material.dart';

import '../models/tour_group.dart';

class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    required this.group,
    required this.isLeader,
    required this.onOpen,
    required this.onTrack,
  });
  final TourGroup group;
  final bool isLeader;
  final VoidCallback onOpen, onTrack;
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
                Icons.groups_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  group.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'More group actions',
                onSelected: (action) => action == 'open' ? onOpen() : onTrack(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'open', child: Text('Manage Group')),
                  PopupMenuItem(value: 'track', child: Text('Open Tracking')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(group.destinationName ?? 'No destination selected'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Text('${group.members.length} members'),
              Text(isLeader ? 'You lead this group' : 'Group member'),
              Text(
                group.trackingEnabled
                    ? 'Demo tracking available'
                    : 'Tracking disabled',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.groups_outlined),
                label: const Text('Open Group'),
                onPressed: onOpen,
              ),
              TextButton.icon(
                icon: const Icon(Icons.map_outlined),
                label: const Text('Track Group'),
                onPressed: onTrack,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
