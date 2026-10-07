import '../../../core/localization/app_localizations.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/heritage_loading.dart';
import '../services/profile_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;
      final profile = ProfileScope.of(context);
      await profile.ready;
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(
          profile.isAuthenticated ? AppRoutes.home : AppRoutes.login,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
      ),
      child: SizedBox.expand(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Image.asset(
                          AppAssets.logo,
                          height: 140,
                          semanticLabel: 'HeritageWalk official logo',
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        AppStrings.appName,
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(
                              color: AppColors.surface,
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      UiText(
                        'Sri Lanka',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(color: AppColors.surface),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      UiText(
                        AppStrings.tagline,
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(color: AppColors.surface),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 64),
                      const HeritageLoading(color: AppColors.surface),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
