import 'package:flutter/material.dart';

import 'discovery_service.dart';
import 'favorites_service.dart';
import 'itinerary_service.dart';

class DiscoveryState extends ChangeNotifier {
  DiscoveryState() {
    itineraries = ItineraryService(discovery);
    for (final service in [discovery, favorites, itineraries]) {
      service.addListener(notifyListeners);
    }
  }
  final discovery = DiscoveryService();
  final favorites = FavoritesService();
  late final ItineraryService itineraries;
  void clearSession() {
    favorites.clear();
    itineraries.clear();
    discovery.setQuery('');
    discovery.setCategory('All');
  }

  @override
  void dispose() {
    for (final service in [discovery, favorites, itineraries]) {
      service.removeListener(notifyListeners);
      service.dispose();
    }
    super.dispose();
  }
}

class DiscoveryScope extends InheritedNotifier<DiscoveryState> {
  const DiscoveryScope({
    super.key,
    required DiscoveryState state,
    required super.child,
  }) : super(notifier: state);
  static DiscoveryState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DiscoveryScope>()!.notifier!;
}
