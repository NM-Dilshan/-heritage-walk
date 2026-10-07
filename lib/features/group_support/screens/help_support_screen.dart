import '../../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../discovery_planning/widgets/discovery_layout.dart';
import '../models/support_request.dart';
import '../services/support_service.dart';
import '../widgets/faq_tile.dart';
import '../widgets/support_request_card.dart';
import '../widgets/support_request_form.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});
  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  String _query = '', _category = 'All';
  void _feedback(String text) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: UiText(text)));
  }

  Future<void> _form(SupportService service, [SupportRequest? request]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => SupportRequestForm(service: service, request: request),
    );
    if (saved == true && mounted) {
      _feedback(
        request == null
            ? 'Support request submitted'
            : 'Support request updated',
      );
    }
  }

  Future<void> _delete(SupportService service, SupportRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const UiText('Delete Support Request?'),
        content: const UiText(
          'This request will be permanently removed from your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const UiText('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const UiText('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      service.deleteSupportRequest(request.id);
      _feedback('Support request deleted');
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = SupportScope.of(context);
    final topics = FaqTopic.topics
        .where(
          (topic) =>
              (_category == 'All' || topic.category == _category) &&
              '${AppLocalizations.text(context, topic.question)} ${AppLocalizations.text(context, topic.answer)} ${AppLocalizations.text(context, topic.category)}'
                  .toLowerCase()
                  .contains(_query.trim().toLowerCase()),
        )
        .toList();
    final requests = service.getSupportRequests();
    return DiscoveryLayout(
      title: 'Help & Support',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiText(
            'How can we help you?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          TextField(
            decoration: InputDecoration(
              hintText: AppLocalizations.text(context, 'Search for help...'),
              prefixIcon: Icon(Icons.search),
              labelText: AppLocalizations.text(context, 'Search help'),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in [
                'All',
                'Account',
                'Tour Planning',
                'Navigation',
                'Group Tours',
                'Safety',
              ])
                FilterChip(
                  label: UiText(category),
                  selected: _category == category,
                  onSelected: (_) => setState(() => _category = category),
                ),
            ],
          ),
          const SizedBox(height: 24),
          UiText(
            'Frequently Asked Questions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (topics.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: UiText('No help topics found'),
            ),
          for (final topic in topics) ...[
            FaqTile(key: ValueKey(topic.question), topic: topic),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => _form(service),
            icon: const Icon(Icons.support_agent),
            label: const UiText('Contact Support'),
          ),
          const SizedBox(height: 12),
          const UiText(
            'Academic demo requests. Requests are not delivered or monitored by a real support team.',
          ),
          const SizedBox(height: 24),
          UiText(
            'My Support Requests',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (requests.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: UiText(
                  'No support requests yet. Use Contact Support to create one.',
                ),
              ),
            ),
          for (final request in requests) ...[
            SupportRequestCard(
              key: ValueKey(request.id),
              request: request,
              onEdit: () => _form(service, request),
              onStatus: () {
                service.markResolved(
                  request.id,
                  resolved: request.status == SupportStatus.open,
                );
                _feedback(
                  request.status == SupportStatus.open
                      ? 'Request marked resolved'
                      : 'Request reopened',
                );
              },
              onDelete: () => _delete(service, request),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  UiText(
                    'Need emergency help?',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.emergency),
                    icon: const Icon(Icons.health_and_safety_outlined),
                    label: const UiText('Open Emergency Support'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }
}
