import 'package:flutter/material.dart';

import 'core/constants/app_strings.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'features/auth_profile/services/profile_service.dart';
import 'features/discovery_planning/services/discovery_scope.dart';

void main() => runApp(const HeritageWalkApp());

class HeritageWalkApp extends StatefulWidget {
  const HeritageWalkApp({super.key, this.initialRoute = AppRoutes.splash});
  final String initialRoute;
  @override
  State<HeritageWalkApp> createState() => _HeritageWalkAppState();
}

class _HeritageWalkAppState extends State<HeritageWalkApp> {
  final _service = ProfileService();
  final _discoveryState = DiscoveryState();
  @override
  void dispose() {
    _service.dispose();
    _discoveryState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProfileScope(
    service: _service,
    child: DiscoveryScope(
      state: _discoveryState,
      child: MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        initialRoute: widget.initialRoute,
        // Create exactly one initial route so the preview isn't below splash/login.
        onGenerateInitialRoutes: (name) => [
          MaterialPageRoute<void>(
            settings: RouteSettings(name: name),
            builder: AppRoutes.routes[name]!,
          ),
        ],
        routes: AppRoutes.routes,
      ),
    ),
  );
}
