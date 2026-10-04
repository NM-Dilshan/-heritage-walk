import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/heritage_app_bar.dart';
import '../../../shared/widgets/main_bottom_navigation.dart';
import '../services/profile_service.dart';
import '../widgets/auth_form_layout.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/sign_out.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final profile = ProfileScope.of(context).profile;
    return Scaffold(
      appBar: const HeritageAppBar(title: 'My Profile', showBackButton: true),
      bottomNavigationBar: const MainBottomNavigation(selectedIndex: 4),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          ProfileAvatar(profile: profile),
                          const SizedBox(height: 16),
                          Text(
                            profile.fullName,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            profile.email,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Column(
                      children: [
                        _menu(
                          context,
                          'Edit Profile',
                          Icons.edit_outlined,
                          asset: AppAssets.edit,
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.editProfile,
                          ),
                        ),
                        const Divider(height: 1),
                        _menu(
                          context,
                          'My Trips',
                          Icons.event_note_outlined,
                          asset: AppAssets.itineraryCalendar,
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.itineraries,
                          ),
                        ),
                        _menu(
                          context,
                          'My Favorites',
                          Icons.favorite_border,
                          asset: AppAssets.favorite,
                          onTap: () =>
                              Navigator.pushNamed(context, AppRoutes.favorites),
                        ),
                        _menu(
                          context,
                          'Notifications',
                          Icons.notifications_outlined,
                          asset: AppAssets.notification,
                        ),
                        _menu(context, 'Language', Icons.language),
                        _menu(
                          context,
                          'Help & Support',
                          Icons.help_outline,
                          asset: AppAssets.help,
                        ),
                        const Divider(height: 1),
                        _menu(
                          context,
                          'Logout',
                          Icons.logout,
                          onTap: () => confirmSignOut(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _menu(
    BuildContext context,
    String title,
    IconData icon, {
    String? asset,
    VoidCallback? onTap,
  }) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    leading: asset == null
        ? Icon(icon, color: Theme.of(context).colorScheme.primary)
        : Image.asset(
            asset,
            width: 24,
            height: 24,
            excludeFromSemantics: true,
            errorBuilder: (_, error, stack) => Icon(icon),
          ),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap ?? () => showFutureFeature(context),
  );
}
