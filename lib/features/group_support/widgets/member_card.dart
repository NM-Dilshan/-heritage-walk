import '../../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../models/group_member.dart';
import 'member_status_chip.dart';

class MemberCard extends StatelessWidget {
  const MemberCard({super.key, required this.member, this.onRemove});
  final GroupMember member;
  final VoidCallback? onRemove;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                child: Text(member.name.characters.first.toUpperCase()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  member.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (onRemove != null)
                IconButton(
                  tooltip: uiFormat(context, 'Remove {0}', [member.name]),
                  icon: Icon(
                    Icons.person_remove_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: onRemove,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (member.isLeader)
                const MemberStatusChip(
                  label: 'Leader',
                  icon: Icons.star_outline,
                ),
              const MemberStatusChip(
                label: 'Check Group Tracking for live sharing status.',
                icon: Icons.location_on_outlined,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
