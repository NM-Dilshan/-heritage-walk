import '../../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/heritage_button.dart';
import '../widgets/sign_out.dart';

class AuthSuccessPlaceholderScreen extends StatelessWidget {
  const AuthSuccessPlaceholderScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  AppAssets.logo,
                  height: 128,
                  semanticLabel: 'HeritageWalk official logo',
                ),
                const SizedBox(height: 24),
                UiText(
                  'Login Successful',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                const UiText(
                  'Home module will be connected in Part 3',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                HeritageButton(
                  label: 'View Profile',
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.profile),
                ),
                const SizedBox(height: 12),
                HeritageButton(
                  label: 'Sign Out',
                  variant: HeritageButtonVariant.outlined,
                  onPressed: () => confirmSignOut(context),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
