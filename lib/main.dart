import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/localization/app_localizations.dart';
import 'features/reviews/services/review_controller.dart';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'features/admin/services/catalog_controller.dart';
import 'features/navigation_guide/services/emergency_controller.dart';
import 'core/firebase/app_services.dart';
import 'core/firebase/cloud_status.dart';
import 'features/auth_profile/screens/login_screen.dart';

import 'core/constants/app_strings.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'features/auth_profile/services/profile_service.dart';
import 'features/discovery_planning/services/discovery_scope.dart';
import 'features/navigation_guide/services/navigation_guide_scope.dart';
import 'features/group_support/services/group_tour_service.dart';
import 'features/group_support/services/language_service.dart';
import 'features/group_support/services/support_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(HeritageWalkApp(services: AppServices.firebase()));
}

class HeritageWalkApp extends StatefulWidget {
  const HeritageWalkApp({
    super.key,
    this.initialRoute = AppRoutes.splash,
    this.services,
  });
  final AppServices? services;
  final String initialRoute;
  @override
  State<HeritageWalkApp> createState() => _HeritageWalkAppState();
}

class _HeritageWalkAppState extends State<HeritageWalkApp>
    with WidgetsBindingObserver {
  late final _services = widget.services ?? AppServices();
  late final _service = _services.profile;
  late final _languageService = _services.language;
  late final _supportService = _services.support;
  late final _groupService = _services.groups;
  late final _discoveryState = _services.discovery;
  late final _navigationGuideState = _services.navigation;
  final _navigator = GlobalKey<NavigatorState>();
  final _routeObserver = _AuthRouteObserver();
  bool _wasAuthenticated = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null) _groupService.sharing.handleLifecycle(lifecycle);
    _wasAuthenticated = _service.isAuthenticated;
    _service.addListener(_authChanged);
  }

  void _authChanged() {
    if (_services.sync != null &&
        _wasAuthenticated != _service.isAuthenticated &&
        _routeObserver.currentName != AppRoutes.splash) {
      final route = _service.isAuthenticated ? AppRoutes.home : AppRoutes.login;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _routeObserver.currentName != route) {
          _navigator.currentState?.pushNamedAndRemoveUntil(route, (_) => false);
        }
      });
    }
    _wasAuthenticated = _service.isAuthenticated;
  }

  Map<String, WidgetBuilder> get _routes => {
    for (final route in AppRoutes.routes.entries)
      route.key: (context) {
        if (_services.sync != null &&
            !_service.isAuthenticated &&
            ![
              AppRoutes.splash,
              AppRoutes.login,
              AppRoutes.register,
              AppRoutes.foundation,
            ].contains(route.key)) {
          return const LoginScreen();
        }
        return route.value(context);
      },
  };
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _groupService.sharing.handleLifecycle(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.removeListener(_authChanged);
    _services.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ReviewScope(
    controller: _services.reviews,
    child: ProfileScope(
      service: _service,
      child: DiscoveryScope(
        state: _discoveryState,
        child: NavigationGuideScope(
          state: _navigationGuideState,
          child: GroupTourScope(
            service: _groupService,
            child: LanguageScope(
              service: _languageService,
              child: SupportScope(
                service: _supportService,
                child: EmergencyScope(
                  controller: _services.emergency,
                  child: CatalogScope(
                    controller: _services.catalog,
                    child: AnimatedBuilder(
                      animation: _languageService,
                      builder: (context, _) => MaterialApp(
                        locale: Locale(_languageService.selectedLanguageCode),
                        supportedLocales: AppLocalizations.supportedLocales,
                        localizationsDelegates: const [
                          AppLocalizations.delegate,
                          GlobalMaterialLocalizations.delegate,
                          GlobalWidgetsLocalizations.delegate,
                          GlobalCupertinoLocalizations.delegate,
                        ],
                        navigatorKey: _navigator,
                        navigatorObservers: [_routeObserver],
                        builder: (context, child) => _services.sync == null
                            ? child!
                            : CloudStatus(
                                sync: _services.sync!,
                                child: child!,
                                onSignOut: () async {
                                  await _service.signOut();
                                },
                              ),
                        title: AppStrings.appName,
                        debugShowCheckedModeBanner: false,
                        theme: AppTheme.light,
                        initialRoute: widget.initialRoute,
                        // Create exactly one initial route so the preview isn't below splash/login.
                        onGenerateInitialRoutes: (name) => [
                          MaterialPageRoute<void>(
                            settings: RouteSettings(name: name),
                            builder: _routes[name]!,
                          ),
                        ],
                        routes: _routes,
                      ),
                    ),
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

class _AuthRouteObserver extends NavigatorObserver {
  String? currentName;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentName = route.settings.name;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    currentName = newRoute?.settings.name;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentName = previousRoute?.settings.name;
  }
}
