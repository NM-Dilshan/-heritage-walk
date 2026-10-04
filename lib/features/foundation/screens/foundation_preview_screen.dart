import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/heritage_app_bar.dart';
import '../../../shared/widgets/heritage_bottom_navigation.dart';
import '../../../shared/widgets/heritage_button.dart';
import '../../../shared/widgets/heritage_text_field.dart';

class FoundationPreviewScreen extends StatefulWidget {
  const FoundationPreviewScreen({super.key});

  @override
  State<FoundationPreviewScreen> createState() =>
      _FoundationPreviewScreenState();
}

class _FoundationPreviewScreenState extends State<FoundationPreviewScreen> {
  int _selectedIndex = 0;

  void _showPreviewMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Foundation preview: application features will be added later.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: const HeritageAppBar(title: 'Foundation preview'),
      bottomNavigationBar: HeritageBottomNavigation(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width < 360 ? 16 : 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    AppAssets.logo,
                    height: 128,
                    fit: BoxFit.contain,
                    semanticLabel: 'HeritageWalk official logo',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.appName,
                    style: textTheme.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.tagline,
                    style: textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'A journey through heritage',
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Discover the stories, culture and natural beauty of Sri Lanka.',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  HeritageButton(
                    label: 'Primary button',
                    onPressed: _showPreviewMessage,
                  ),
                  const SizedBox(height: 12),
                  HeritageButton(
                    label: 'Outlined button',
                    onPressed: _showPreviewMessage,
                    variant: HeritageButtonVariant.outlined,
                  ),
                  const SizedBox(height: 24),
                  const HeritageTextField(
                    label: 'Search heritage places',
                    hint: 'Enter a place name',
                    prefixIcon: Icon(Icons.search),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.account_balance_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Preserve every story',
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Respect local communities and help protect our heritage for future generations.',
                            style: textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
