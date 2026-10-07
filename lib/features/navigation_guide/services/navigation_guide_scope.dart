import 'location_service.dart';
import 'routing_service.dart';

import 'package:flutter/material.dart';

import 'navigation_service.dart';
import 'guide_notes_service.dart';
import 'facility_service.dart';
import 'emergency_service.dart';

class NavigationGuideState extends ChangeNotifier {
  NavigationGuideState({
    LocationService? location,
    RoutingService? routing,
    NearbyFacilityService? facilities,
    this.tilesEnabled = true,
  }) : navigation = NavigationService(location: location, routing: routing),
       facilities = facilities ?? UnavailableNearbyFacilityService() {
    navigation.addListener(notifyListeners);
    notes.addListener(notifyListeners);
  }
  final NavigationService navigation;
  final bool tilesEnabled;
  final notes = GuideNotesService();
  final NearbyFacilityService facilities;
  final emergency = EmergencyService();
  void clearSession() {
    navigation.clear();
    notes.clear();
    facilities.clearCache();
  }

  @override
  void dispose() {
    navigation.removeListener(notifyListeners);
    notes.removeListener(notifyListeners);
    navigation.dispose();
    notes.dispose();
    facilities.dispose();
    super.dispose();
  }
}

class NavigationGuideScope extends InheritedNotifier<NavigationGuideState> {
  const NavigationGuideScope({
    super.key,
    required NavigationGuideState state,
    required super.child,
  }) : super(notifier: state);
  static NavigationGuideState of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<NavigationGuideScope>()!
      .notifier!;
}
