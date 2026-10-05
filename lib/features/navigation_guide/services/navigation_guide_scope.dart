import 'package:flutter/material.dart';

import 'navigation_service.dart';
import 'guide_notes_service.dart';
import 'facility_service.dart';
import 'emergency_service.dart';

class NavigationGuideState extends ChangeNotifier {
  NavigationGuideState() {
    navigation.addListener(notifyListeners);
    notes.addListener(notifyListeners);
  }
  final navigation = NavigationService();
  final notes = GuideNotesService();
  final facilities = FacilityService();
  final emergency = EmergencyService();
  void clearSession() {
    navigation.clear();
    notes.clear();
  }

  @override
  void dispose() {
    navigation.removeListener(notifyListeners);
    notes.removeListener(notifyListeners);
    navigation.dispose();
    notes.dispose();
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
