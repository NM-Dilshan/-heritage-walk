import '../../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/routes/app_routes.dart';
import '../../discovery_planning/widgets/discovery_layout.dart';
import '../widgets/about_feature_card.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) => DiscoveryLayout(
    title: 'About HeritageWalk',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Image.asset(
                  AppAssets.logo,
                  width: 160,
                  height: 160,
                  semanticLabel: 'Official HeritageWalk logo',
                ),
                const SizedBox(height: 16),
                UiText(
                  'HeritageWalk Sri Lanka',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const UiText(
                  "Discover, plan, and experience Sri Lanka's cultural and historical heritage through one connected travel experience.",
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        UiText('Our Purpose', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        const UiText(
          'Find heritage places, plan tours, read guides and explore with groups using real GPS and route previews.',
        ),
        const SizedBox(height: 24),
        UiText('Key Features', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        for (final feature in const [
          AboutFeatureCard(
            title: 'Discover Heritage',
            description: 'Search and filter curated heritage places; save your favorites.',
            icon: Icons.explore_outlined,
          ),
          AboutFeatureCard(
            title: 'Tour Planning',
            description:
                'Generate, save and manage itineraries in your account.',
            icon: Icons.event_note_outlined,
          ),
          AboutFeatureCard(
            title: 'Digital Guide',
            description:
                'Read destination guides and keep personal saved notes.',
            icon: Icons.menu_book_outlined,
          ),
          AboutFeatureCard(
            title: 'Navigation',
            description: 'Preview real walking or driving routes and follow your current GPS position.',
            icon: Icons.route_outlined,
          ),
          AboutFeatureCard(
            title: 'Group Tours',
            description: 'Manage groups and invite members. Share current location only with explicit foreground consent.',
            icon: Icons.groups_outlined,
          ),
          AboutFeatureCard(
            title: 'Safety Support',
            description: 'Access verified emergency contacts and OpenStreetMap nearby facilities.',
            icon: Icons.health_and_safety_outlined,
          ),
        ]) ...[feature, const SizedBox(height: 12)],
        const SizedBox(height: 12),
        UiText(
          'Academic Project',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        const UiText(
          'HeritageWalk Sri Lanka is a university Human–Computer Interaction project exploring accessible heritage travel experiences.',
        ),
        const SizedBox(height: 24),
        UiText('Version 1.0.0', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 24),
        UiText('Data Notice', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        const UiText(
          'Profile and saved content use Firebase. Map tiles and routes need internet. Individual GPS is not stored; group snapshots require consent. Support requests are academic records, not monitored messages.',
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.helpSupport),
              child: const UiText('Help & Support'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.language),
              child: const UiText('Language'),
            ),
            FilledButton(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.home,
                (_) => false,
              ),
              child: const UiText('Back to Home'),
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    ),
  );
}
