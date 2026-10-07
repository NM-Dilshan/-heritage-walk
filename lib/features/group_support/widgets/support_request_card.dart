import '../../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../../discovery_planning/widgets/discovery_layout.dart';
import '../models/support_request.dart';

class SupportRequestCard extends StatelessWidget {
  const SupportRequestCard({
    super.key,
    required this.request,
    required this.onEdit,
    required this.onStatus,
    required this.onDelete,
  });
  final SupportRequest request;
  final VoidCallback onEdit, onStatus, onDelete;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(request.subject, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          UiText(
            "{0} • Created {1}",
            args: [
              AppLocalizations.text(context, request.category.label),
              formatTourDate(request.createdAt),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              avatar: Icon(
                request.status == SupportStatus.open
                    ? Icons.pending_outlined
                    : Icons.check_circle_outline,
                size: 18,
              ),
              label: UiText(
                request.status == SupportStatus.open ? 'Open' : 'Resolved',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(request.message),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const UiText('Edit'),
              ),
              TextButton.icon(
                onPressed: onStatus,
                icon: const Icon(Icons.check_circle_outline),
                label: UiText(
                  request.status == SupportStatus.open
                      ? 'Mark Resolved'
                      : 'Reopen',
                ),
              ),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                label: const UiText('Delete'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
