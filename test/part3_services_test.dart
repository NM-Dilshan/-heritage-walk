import 'package:flutter_test/flutter_test.dart';
import 'package:heritage_walk/features/discovery_planning/models/heritage_place.dart';
import 'package:heritage_walk/features/discovery_planning/models/itinerary.dart';
import 'package:heritage_walk/features/discovery_planning/services/discovery_scope.dart';
import 'package:heritage_walk/features/discovery_planning/services/discovery_service.dart';
import 'package:heritage_walk/features/discovery_planning/services/favorites_service.dart';

TourPlan plan({
  String destination = 'Sigiriya',
  String duration = '1 Day',
  String style = 'Balanced',
  List<String> interests = const ['History'],
  DateTime? date,
}) => TourPlan(
  destination: destination,
  date: date ?? DateTime.now().add(const Duration(days: 5)),
  duration: duration,
  interests: interests,
  travelStyle: style,
);
void main() {
  test(
    'Search covers name, city, district and category and combines filters',
    () {
      final service = DiscoveryService();
      addTearDown(service.dispose);
      expect(service.search(query: 'SIGIRIYA').single.id, 'sigiriya');
      expect(service.search(query: 'Ella').single.id, 'nine-arch');
      expect(service.search(query: 'Matale').length, 2);
      expect(service.search(query: 'Temples').length, 2);
      expect(
        service.search(query: 'Matale', category: 'Forts').single.id,
        'sigiriya',
      );
      expect(service.search(category: 'Nature'), isEmpty);
    },
  );
  test('Favorites use unique IDs and implement add/read/remove/toggle', () {
    final service = FavoritesService();
    final discovery = DiscoveryService();
    addTearDown(service.dispose);
    addTearDown(discovery.dispose);
    final place = discovery.places.first;
    service.addFavorite(place);
    service.addFavorite(place);
    expect(service.getFavorites(), [place]);
    expect(service.isFavorite(place.id), isTrue);
    service.removeFavorite(place.id);
    expect(service.getFavorites(), isEmpty);
    service.toggleFavorite(place);
    expect(service.isFavorite(place.id), isTrue);
    service.toggleFavorite(place);
    expect(service.getFavorites(), isEmpty);
  });
  test('Itinerary save is unique, rename and delete update the same state', () {
    final state = DiscoveryState();
    addTearDown(state.dispose);
    final item = state.itineraries.generate(plan());
    expect(state.itineraries.save(item.id), isTrue);
    expect(state.itineraries.save(item.id), isFalse);
    expect(state.itineraries.savedItineraries.length, 1);
    state.itineraries.rename(item.id, ' New title ');
    expect(state.itineraries.find(item.id)!.title, 'New title');
    expect(() => state.itineraries.rename(item.id, '  '), throwsArgumentError);
    state.itineraries.delete(item.id);
    expect(state.itineraries.find(item.id), isNull);
    expect(state.itineraries.savedItineraries, isEmpty);
  });
  test('Destination, interests and pace guide local recommendations', () {
    final state = DiscoveryState();
    addTearDown(state.dispose);
    final temple = state.itineraries.generate(
      plan(interests: ['Religious Sites']),
    );
    expect(temple.places.first.id, 'dambulla');
    final architecture = state.itineraries.generate(
      plan(interests: ['Architecture']),
    );
    expect(architecture.places.first.id, 'sigiriya');
    expect(state.itineraries.generate(plan(style: 'Relaxed')).places.length, 1);
    expect(
      state.itineraries.generate(plan(duration: 'Half Day')).places.length,
      1,
    );
    expect(
      state.itineraries.generate(plan(destination: 'Galle')).places.single.id,
      'galle-fort',
    );
    final regenerated = state.itineraries.generate(
      architecture.plan,
      previous: architecture,
    );
    expect(regenerated.places.first.id, isNot(architecture.places.first.id));
  });
  test('Invalid and past-date plans are rejected by the service', () {
    final state = DiscoveryState();
    addTearDown(state.dispose);
    expect(
      () => state.itineraries.generate(plan(destination: 'unknown')),
      throwsArgumentError,
    );
    expect(
      () => state.itineraries.generate(plan(interests: [])),
      throwsArgumentError,
    );
    expect(
      () => state.itineraries.generate(plan(duration: 'week')),
      throwsArgumentError,
    );
    expect(
      () => state.itineraries.generate(
        plan(date: DateTime.now().subtract(const Duration(days: 1))),
      ),
      throwsArgumentError,
    );
  });
  test(
    'Place and itinerary maps round-trip without Firebase or mutable lists',
    () {
      final state = DiscoveryState();
      addTearDown(state.dispose);
      final place = state.discovery.places.first;
      expect(HeritagePlace.fromMap(place.toMap()).toMap(), place.toMap());
      final item = state.itineraries.generate(plan());
      expect(Itinerary.fromMap(item.toMap()).toMap(), item.toMap());
      expect(() => item.places.clear(), throwsUnsupportedError);
      expect(() => item.interests.clear(), throwsUnsupportedError);
    },
  );
  test(
    'Ending a session clears favorites, saved journeys and search selections',
    () {
      final state = DiscoveryState();
      addTearDown(state.dispose);
      state.favorites.addFavorite(state.discovery.places.first);
      state.itineraries.save(state.itineraries.generate(plan()).id);
      state.discovery.setQuery('Sigiriya');
      state.discovery.setCategory('Forts');
      state.clearSession();
      expect(state.favorites.getFavorites(), isEmpty);
      expect(state.itineraries.savedItineraries, isEmpty);
      expect(state.itineraries.draftPlan, isNull);
      expect(state.discovery.query, isEmpty);
      expect(state.discovery.category, 'All');
    },
  );
}
