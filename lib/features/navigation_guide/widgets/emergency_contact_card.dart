import '../../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../models/emergency_contact.dart';
import '../services/emergency_service.dart';
import '../../../core/firebase/backend_error.dart';

class EmergencyContactCard extends StatelessWidget {
  const EmergencyContactCard({super.key, required this.contact, this.onCall});
  final EmergencyContact contact;
  final Future<void> Function()? onCall;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(contact.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(contact.description),
          const SizedBox(height: 12),
          UiText(
            contact.phoneNumber ??
                'Number will be provided through verified service data',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.phone_outlined),
            label: UiText(onCall == null ? 'Call (not connected)' : 'Call'),
            onPressed: onCall == null
                ? () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: UiText(EmergencyService.callingMessage),
                    ),
                  )
                : () async {
                    try {
                      await onCall!();
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: UiText(backendMessage(error))),
                        );
                      }
                    }
                  },
          ),
        ],
      ),
    ),
  );
}
