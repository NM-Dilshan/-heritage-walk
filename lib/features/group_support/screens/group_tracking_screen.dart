import '../../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/heritage_button.dart';
import '../../discovery_planning/services/discovery_scope.dart';
import '../../discovery_planning/widgets/discovery_layout.dart';
import '../../navigation_guide/widgets/heritage_map.dart';
import '../../navigation_guide/services/location_service.dart';
import '../services/group_tour_service.dart';
import '../services/group_location_service.dart';
import 'group_details_screen.dart';

class GroupTrackingScreen extends StatefulWidget {
  const GroupTrackingScreen({super.key, this.groupId});
  final String? groupId;
  @override
  State<GroupTrackingScreen> createState() => _GroupTrackingScreenState();
}

class _GroupTrackingScreenState extends State<GroupTrackingScreen> {
  GroupLocationSession? session;
  GroupLocationSharingController? sharing;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindSession();
  }

  void _bindSession() {
    if (session != null || widget.groupId == null) return;
    final groups = GroupTourScope.of(context);
    sharing = groups.sharing;
    session = sharing!.acquire(widget.groupId!);
  }

  @override
  void didUpdateWidget(GroupTrackingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId) {
      if (session != null) sharing?.release(session!.groupId);
      session = null;
      sharing = null;
      _bindSession();
    }
  }

  @override
  void dispose() {
    if (session != null) sharing?.release(session!.groupId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = GroupTourScope.of(context);
    final group = widget.groupId == null
        ? null
        : groups.getGroupById(widget.groupId!);
    if (group == null || !groups.isMember(group) || session == null) {
      return unavailableGroup(context, 'Group Tracking');
    }
    final destination = DiscoveryScope.of(context).discovery.places
        .where((p) => p.id == group.destinationPlaceId)
        .firstOrNull;
    return AnimatedBuilder(
      animation: session!,
      builder: (context, _) {
        final s = session!;
        final fresh = s.freshLocations;
        return DiscoveryLayout(
          title: 'Group Tracking',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                group.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              UiText(
                "Destination: {0}",
                args: [
                  group.destinationName ??
                      AppLocalizations.text(context, 'Not selected'),
                ],
              ),
              HeritageMap(
                tilesEnabled: groups.tilesEnabled,
                fitMarkers: true,
                groupRecenter: true,
                markers: fresh
                    .map(
                      (l) => HeritageMapMarker(
                        l.userId,
                        l.position,
                        l.userId == groups.currentUserId
                            ? AppLocalizations.text(context, 'You')
                            : l.displayName,
                        current: l.userId == groups.currentUserId,
                      ),
                    )
                    .toList(),
              ),
              UiText(
                s.sharing ? 'Sharing ON' : 'Sharing OFF',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const UiText(
                'Only this group can see your current position. Sharing continues across screens for up to 5 minutes and stops when the app leaves the foreground. No location history is saved.',
              ),
              HeritageButton(
                label: s.sharing
                    ? 'Stop Sharing Location'
                    : 'Start Sharing Location',
                isLoading: s.busy,
                onPressed: s.sharing
                    ? sharing!.stop
                    : () => sharing!.start(s.groupId),
              ),
              if (s.error != null) ...[
                UiText(s.error!),
                TextButton(onPressed: s.retry, child: const UiText('Retry')),
              ],
              if (s.locationState == LocationState.deniedForever ||
                  s.locationState == LocationState.servicesOff)
                TextButton(
                  onPressed: () => groups.location.openSettings(
                    device: s.locationState == LocationState.servicesOff,
                  ),
                  child: UiText(
                    s.locationState == LocationState.servicesOff
                        ? 'Enable Location'
                        : 'Open Settings',
                  ),
                ),
              const SizedBox(height: 16),
              UiText('Members', style: Theme.of(context).textTheme.titleLarge),
              for (final member in group.members)
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(member.name),
                  subtitle: UiText(
                    fresh.any((l) => l.userId == member.id)
                        ? 'Current location available'
                        : s.locations.any((l) => l.userId == member.id)
                        ? 'Location stale or sharing stopped'
                        : 'Location not shared',
                  ),
                ),
              if (destination != null) ...[
                HeritageButton(
                  label: 'View Destination',
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.placeDetails,
                      arguments: destination,
                    );
                  },
                ),
                const SizedBox(height: 12),
                HeritageButton(
                  label: 'Navigate',
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.navigation,
                      arguments: destination,
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
