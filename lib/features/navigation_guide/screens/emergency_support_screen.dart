import '../../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../../../shared/widgets/heritage_button.dart';
import '../../discovery_planning/widgets/discovery_layout.dart';
import '../../discovery_planning/widgets/section_header.dart';
import '../services/emergency_service.dart';
import '../services/navigation_guide_scope.dart';
import '../widgets/emergency_contact_card.dart';
import '../services/emergency_controller.dart';

class EmergencySupportScreen extends StatelessWidget {
  const EmergencySupportScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final emergency = EmergencyScope.of(context);
    return DiscoveryLayout(
      title: 'Emergency Support',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiText(
            'Get help when you need it',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.emergency_outlined,
                    size: 40,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(height: 12),
                  UiText(
                    'Emergency contact access',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  UiText(
                    emergency.isCloud
                        ? 'Contacts marked active and verified by an administrator are listed below. Call opens your phone dialer; you decide whether to place the call.'
                        : 'Calling and verified contact data are not connected in this demo. Use verified emergency services when necessary.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SectionHeader(
            title: emergency.isCloud
                ? 'Verified emergency contacts'
                : 'Contact categories',
          ),
          if (emergency.isCloud) ...[
            if (emergency.loading)
              const Center(child: CircularProgressIndicator()),
            if (emergency.error != null) ...[
              UiText(emergency.error!),
              TextButton(
                onPressed: emergency.reload,
                child: const UiText('Reload contacts'),
              ),
            ],
            if (!emergency.loading &&
                emergency.error == null &&
                emergency.contacts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: UiText('No active verified contacts are available.'),
              ),
            for (final contact in emergency.contacts)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: EmergencyContactCard(
                  contact: contact,
                  onCall: () => emergency.call(contact),
                ),
              ),
          ] else
            for (final contact in NavigationGuideScope.of(
              context,
            ).emergency.getContacts())
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: EmergencyContactCard(contact: contact),
              ),
          const SizedBox(height: 8),
          HeritageButton(
            label: 'Share My Location',
            variant: HeritageButtonVariant.outlined,
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: UiText(EmergencyService.sharingMessage)),
            ),
          ),
          const SectionHeader(title: 'Safety Tips'),
          for (final tip in [
            'Stay aware of your surroundings',
            'Keep important belongings secure',
            'Follow official site guidance',
            'Contact verified emergency services when necessary',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('- ${AppLocalizations.text(context, tip)}'),
            ),
          const SizedBox(height: 96),
        ],
      ),
    );
  }
}
