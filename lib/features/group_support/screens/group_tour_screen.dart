import '../../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/heritage_button.dart';
import '../../discovery_planning/widgets/discovery_layout.dart';
import '../../discovery_planning/widgets/section_header.dart';
import '../services/group_tour_service.dart';
import '../widgets/group_card.dart';
import '../widgets/group_dialogs.dart';

class GroupTourScreen extends StatelessWidget {
  const GroupTourScreen({super.key});
  Future<void> _join(BuildContext context) async {
    final service = GroupTourScope.of(context);
    final id = await showDialog<String>(
      context: context,
      builder: (_) => JoinGroupDialog(service: service),
    );
    if (id != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: UiText('Group joined')));
      Navigator.pushNamed(context, AppRoutes.groupDetails, arguments: id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = GroupTourScope.of(context);
    final groups = service.getGroups().where(service.isMember).toList();
    return DiscoveryLayout(
      title: 'Group Tours',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiText(
            'Explore Sri Lanka together',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const UiText(
            'Signed-in groups and membership are saved to your account. Invite codes let other signed-in users join.',
          ),
          const SizedBox(height: 24),
          HeritageButton(
            label: '+ Create Group',
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.createGroup),
          ),
          const SizedBox(height: 12),
          HeritageButton(
            label: 'Join with Code',
            variant: HeritageButtonVariant.outlined,
            onPressed: () => _join(context),
          ),
          if (groups.isEmpty)
            DiscoveryEmptyState(
              title: 'No group tours yet',
              message: 'Create a group and explore heritage sites together.',
              icon: Icons.groups_outlined,
              buttonLabel: 'Create Your First Group',
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.createGroup),
            ),
          if (groups.isNotEmpty) const SectionHeader(title: 'My Groups'),
          for (final group in groups)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GroupCard(
                group: group,
                isLeader: service.isLeader(group),
                onOpen: () => Navigator.pushNamed(
                  context,
                  AppRoutes.groupDetails,
                  arguments: group.id,
                ),
                onTrack: () => Navigator.pushNamed(
                  context,
                  AppRoutes.groupTracking,
                  arguments: group.id,
                ),
              ),
            ),
          const SizedBox(height: 96),
        ],
      ),
    );
  }
}
