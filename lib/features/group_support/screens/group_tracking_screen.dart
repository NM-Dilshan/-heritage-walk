import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/heritage_button.dart';
import '../../discovery_planning/services/discovery_scope.dart';
import '../../discovery_planning/widgets/discovery_layout.dart';
import '../../discovery_planning/widgets/section_header.dart';
import '../services/group_tour_service.dart';
import '../widgets/group_map_placeholder.dart';
import '../widgets/member_card.dart';
import 'group_details_screen.dart';

class GroupTrackingScreen extends StatelessWidget {
  const GroupTrackingScreen({super.key, this.groupId});
  final String? groupId;
  @override
  Widget build(BuildContext context) {
    final service = GroupTourScope.of(context);
    final group = groupId == null ? null : service.getGroupById(groupId!);
    if (group == null || !service.isMember(group)) {
      return unavailableGroup(context, 'Group Tracking');
    }
    final matches = DiscoveryScope.of(context).discovery.places
        .where((place) => place.id == group.destinationPlaceId);
    final destination = matches.isEmpty ? null : matches.first;
    final currentMember = group.members.firstWhere(
      (member) => member.id == service.currentUserId,
    );
    return DiscoveryLayout(
      title: 'Group Tracking',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: () {
            service.refreshTracking(group.id);
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Demo tracking refreshed')),
            );
          },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(group.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Destination: ${group.destinationName ?? 'Not selected'}'),
          const SizedBox(height: 8),
          Text('${group.members.length} members'),
          const SizedBox(height: 20),
          GroupMapPlaceholder(group: group),
          const SizedBox(height: 20),
          Card(
            child: SwitchListTile(
              title: const Text('Share My Location'),
              subtitle: const Text(
                'Controls demo sharing only. No GPS access.',
              ),
              value: currentMember.isSharingLocation,
              onChanged: (enabled) {
                service.toggleMemberLocationSharing(
                  group.id,
                  currentMember.id,
                  enabled,
                );
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      enabled
                          ? 'Demo location sharing enabled'
                          : 'Location sharing disabled',
                    ),
                  ),
                );
              },
            ),
          ),
          const SectionHeader(title: 'Members'),
          for (final member in group.members)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MemberCard(member: member),
            ),
          const SectionHeader(title: 'Destination'),
          Text(group.destinationName ?? 'Not selected'),
          if (destination != null) ...[
            const SizedBox(height: 20),
            HeritageButton(
              label: 'View Destination',
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.placeDetails,
                arguments: destination,
              ),
            ),
            const SizedBox(height: 12),
            HeritageButton(
              label: 'Navigate',
              variant: HeritageButtonVariant.outlined,
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.navigation,
                arguments: destination,
              ),
            ),
          ],
          const SizedBox(height: 120),
        ],
      ),
    );
  }
}
