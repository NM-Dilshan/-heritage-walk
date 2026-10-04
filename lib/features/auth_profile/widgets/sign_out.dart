import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../services/profile_service.dart';
import '../../discovery_planning/services/discovery_scope.dart';

Future<void> confirmSignOut(BuildContext context) async {
  final service = ProfileScope.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sign out'),
      content: const Text('Are you sure you want to sign out?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Sign Out'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    ScaffoldMessenger.of(context).clearSnackBars();
    DiscoveryScope.of(context).clearSession();
    service.signOut();
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }
}
