import '../../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

class FaqTopic {
  const FaqTopic(this.question, this.answer, this.category);
  final String question, answer, category;
  static const topics = [
    FaqTopic(
      'How do I create an itinerary?',
      'Open Plan Tour from Home, select your destinations and preferences, then generate and save the itinerary.',
      'Tour Planning',
    ),
    FaqTopic(
      'How do I save a heritage place?',
      'Tap the favorite heart on a place. Signed-in favorites are saved to your account and appear in My Favorites.',
      'Tour Planning',
    ),
    FaqTopic(
      'How do I create a group tour?',
      'Open Group Tours from Home or Profile, choose Create Group, enter a name and select a destination. You become the group leader.',
      'Group Tours',
    ),
    FaqTopic(
      'How do I join a group?',
      'Choose Join with Code in Group Tours. Signed-in users can join a saved group using its invite code.',
      'Group Tours',
    ),
    FaqTopic(
      'How does navigation work?',
      'Select a place and tap Navigate. Allow GPS to preview a real route. Start Route Guidance for live location; voice guidance is not provided.',
      'Navigation',
    ),
    FaqTopic(
      'How do I change my language?',
      'Open Profile → Language and choose English, Sinhala or Tamil. The app updates and saves your signed-in preference.',
      'Account',
    ),
    FaqTopic(
      'How do I edit my profile?',
      'Open Profile → Edit Profile. Save your changes to your signed-in account.',
      'Account',
    ),
    FaqTopic(
      'How do I contact support?',
      'Use Contact Support below to create an academic support request. You can edit, resolve or delete it. Requests are saved for signed-in users but are not sent to a real support team.',
      'Account',
    ),
    FaqTopic(
      'Where can I find emergency help?',
      'Use Open Emergency Support below for the existing safety screen. Local support requests are not monitored for emergencies.',
      'Safety',
    ),
  ];
}

class FaqTile extends StatelessWidget {
  const FaqTile({super.key, required this.topic});
  final FaqTopic topic;
  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      title: UiText(topic.question),
      subtitle: UiText(topic.category),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [UiText(topic.answer)],
    ),
  );
}
