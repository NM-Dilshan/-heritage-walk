import '../../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../services/profile_service.dart';
import '../../discovery_planning/services/discovery_scope.dart';
import '../../navigation_guide/services/navigation_guide_scope.dart';
import '../../group_support/services/group_tour_service.dart';
import '../../group_support/services/support_service.dart';
import '../../../core/firebase/backend_error.dart';

Future<void> confirmSignOut(BuildContext context) async {
  final service = ProfileScope.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const UiText('Sign out'),
      content: const UiText('Are you sure you want to sign out?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const UiText('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const UiText('Sign Out'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    try {
      await service.signOut();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: UiText(backendMessage(error))));
      }
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    DiscoveryScope.of(context).clearSession();
    NavigationGuideScope.of(context).clearSession();
    GroupTourScope.of(context).clear();
    SupportScope.of(context).clear();
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }
}
