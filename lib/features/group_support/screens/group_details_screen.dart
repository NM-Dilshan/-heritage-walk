import '../../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/heritage_button.dart';
import '../../discovery_planning/models/heritage_place.dart';
import '../../discovery_planning/widgets/discovery_layout.dart';
import '../../discovery_planning/widgets/section_header.dart';
import '../models/group_member.dart';
import '../models/tour_group.dart';
import '../services/group_tour_service.dart';
import '../widgets/group_dialogs.dart';
import '../widgets/invite_code_card.dart';
import '../widgets/member_card.dart';

/// Supporting management view, not an additional assigned main screen.
class GroupDetailsScreen extends StatelessWidget {
  const GroupDetailsScreen({super.key, this.groupId});
  final String? groupId;
  Future<void> _rename(BuildContext context, TourGroup group) async {
    final service = GroupTourScope.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => GroupTextDialog(
        title: 'Rename Group',
        label: 'Group Name',
        initialText: group.name,
      ),
    );
    if (name != null && context.mounted) service.renameGroup(group.id, name);
  }

  Future<void> _destination(BuildContext context, TourGroup group) async {
    final service = GroupTourScope.of(context);
    final destination = await showDialog<HeritagePlace>(
      context: context,
      builder: (_) => GroupDestinationDialog(placeId: group.destinationPlaceId),
    );
    if (destination != null && context.mounted) {
      service.updateDestination(group.id, destination);
    }
  }

  Future<void> _addMember(BuildContext context, TourGroup group) async {
    final service = GroupTourScope.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) =>
          const GroupTextDialog(title: 'Add Demo Member', label: 'Member Name'),
    );
    if (name != null && context.mounted) service.addMember(group.id, name);
  }

  Future<void> _removeMember(
    BuildContext context,
    TourGroup group,
    GroupMember member,
  ) async {
    final service = GroupTourScope.of(context);
    final confirmed = await confirmGroupAction(
      context,
      'Remove this member from the group?',
      member.name,
      'Remove',
      translateMessage: false,
    );
    if (confirmed && context.mounted) service.removeMember(group.id, member.id);
  }

  Future<void> _delete(BuildContext context, TourGroup group) async {
    final service = GroupTourScope.of(context);
    final confirmed = await confirmGroupAction(
      context,
      'Delete Group?',
      'This will permanently delete the group and invalidate its invite code.',
      'Delete',
    );
    if (!confirmed || !context.mounted) return;
    service.deleteGroup(group.id);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: UiText('Group deleted')));
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.groupTours,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = GroupTourScope.of(context);
    final group = groupId == null ? null : service.getGroupById(groupId!);
    if (group == null || !service.isMember(group)) {
      return unavailableGroup(context, 'Group Management');
    }
    final leader = service.isLeader(group);
    return DiscoveryLayout(
      title: 'Group Management',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(group.name, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          group.destinationName == null
              ? const UiText('No destination selected')
              : Text(group.destinationName!),
          const SizedBox(height: 8),
          UiText("Leader: {0}", args: [group.leaderName]),
          const SizedBox(height: 20),
          InviteCodeCard(code: group.inviteCode),
          const SizedBox(height: 20),
          HeritageButton(
            label: 'Open Group Tracking',
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.groupTracking,
              arguments: group.id,
            ),
          ),
          if (leader) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.edit_outlined),
                  label: const UiText('Rename Group'),
                  onPressed: () => _rename(context, group),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.place_outlined),
                  label: const UiText('Change Destination'),
                  onPressed: () => _destination(context, group),
                ),
              ],
            ),
          ],
          SectionHeader(
            title: 'Members',
            subtitle: uiFormat(context, '{0} members', [group.members.length]),
          ),
          for (final member in group.members)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MemberCard(
                member: member,
                onRemove: leader && !member.isLeader
                    ? () => _removeMember(context, group, member)
                    : null,
              ),
            ),
          if (leader) ...[
            const SizedBox(height: 12),
            HeritageButton(
              label: 'Add Demo Member',
              variant: HeritageButtonVariant.outlined,
              onPressed: () => _addMember(context, group),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              icon: const Icon(Icons.delete_outline),
              label: const UiText('Delete Group'),
              onPressed: () => _delete(context, group),
            ),
          ],
          const SizedBox(height: 120),
        ],
      ),
    );
  }
}

Widget unavailableGroup(BuildContext context, String title) => DiscoveryLayout(
  title: title,
  child: DiscoveryEmptyState(
    title: 'Group unavailable',
    message: 'Choose a group you belong to from Group Tours.',
    icon: Icons.groups_outlined,
    buttonLabel: 'Go to Group Tours',
    onPressed: () =>
        Navigator.pushReplacementNamed(context, AppRoutes.groupTours),
  ),
);
