import '../../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../../discovery_planning/widgets/discovery_layout.dart';
import '../services/language_service.dart';
import '../widgets/language_option_card.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final service = LanguageScope.of(context);
    return DiscoveryLayout(
      title: 'Language',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiText(
            'Choose your preferred language',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const UiText(
            'Your language updates the app and is saved to your signed-in account.',
          ),
          const SizedBox(height: 24),
          for (final language in service.getAvailableLanguages()) ...[
            LanguageOptionCard(
              language: language,
              selected: service.selectedLanguageCode == language.code,
              onTap: () {
                service.setLanguage(language.code);
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: UiText('Language preference updated'),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UiText(
                    'Preview',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    service.getSelectedLanguage().preview,
                    key: const Key('language-preview'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
