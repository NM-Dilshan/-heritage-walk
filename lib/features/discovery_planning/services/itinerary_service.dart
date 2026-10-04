import 'package:flutter/foundation.dart';

import '../models/heritage_place.dart';
import '../models/itinerary.dart';
import 'discovery_service.dart';

class ItineraryService extends ChangeNotifier {
  ItineraryService(this.discovery);
  final DiscoveryService discovery;
  static const durations = ['Half Day', '1 Day', '2 Days', '3 Days'];
  static const interests = [
    'History',
    'Religious Sites',
    'Architecture',
    'Nature',
    'Photography',
    'Museums',
  ];
  static const styles = ['Relaxed', 'Balanced', 'Packed'];
  final Map<String, Itinerary> _items = {};
  int _sequence = 0;
  TourPlan? draftPlan;
  List<Itinerary> get savedItineraries =>
      List.unmodifiable(_items.values.where((item) => item.isSaved));
  Itinerary? find(String id) => _items[id];

  Itinerary generate(TourPlan plan, {Itinerary? previous}) {
    final today = DateTime.now();
    if (!DiscoveryService.destinations.contains(plan.destination) ||
        !durations.contains(plan.duration) ||
        plan.interests.isEmpty ||
        plan.interests.any((interest) => !interests.contains(interest)) ||
        !styles.contains(plan.travelStyle) ||
        DateTime(
          plan.date.year,
          plan.date.month,
          plan.date.day,
        ).isBefore(DateTime(today.year, today.month, today.day))) {
      throw ArgumentError(
        'Choose a destination, future date, duration and interests.',
      );
    }
    draftPlan = plan;
    // The small catalogue only supports destination-local stops and the
    // Sigiriya/Dambulla pair. No GPS, travel times or route optimization.
    final candidates = discovery.places
        .where(
          (place) =>
              place.city == plan.destination ||
              (['Sigiriya', 'Dambulla'].contains(plan.destination) &&
                  ['Sigiriya', 'Dambulla'].contains(place.city)),
        )
        .toList();
    int score(HeritagePlace place) => plan.interests.fold(
      0,
      (score, interest) =>
          score +
          switch (interest) {
            'Religious Sites' => place.category == 'Temples' ? 3 : 0,
            'History' =>
              ['Ancient Cities', 'Forts', 'Temples'].contains(place.category)
                  ? 2
                  : 0,
            'Architecture' =>
              ['Architecture', 'Forts'].contains(place.category) ? 2 : 0,
            'Nature' => place.category == 'Nature' ? 3 : 0,
            'Photography' => 1,
            _ => 0,
          },
    );
    candidates.sort((a, b) {
      final rank = score(b).compareTo(score(a));
      return rank != 0 ? rank : a.id.compareTo(b.id);
    });
    if (previous != null && candidates.length > 1) {
      final firstId = previous.places.first.id;
      if (candidates.first.id == firstId) {
        candidates.add(candidates.removeAt(0));
      }
    }
    final limit = plan.duration == 'Half Day' || plan.travelStyle == 'Relaxed'
        ? 1
        : 3;
    final selected = candidates.take(limit).toList();
    if (previous != null &&
        selected.length == 1 &&
        candidates.length > 1 &&
        selected.first.id == previous.places.first.id) {
      selected[0] = candidates[1];
    }
    final now = DateTime.now();
    final result = Itinerary(
      id: 'itinerary-${now.microsecondsSinceEpoch}-${_sequence++}',
      title: '${plan.destination} Heritage Journey',
      plan: plan,
      places: selected,
      createdAt: now,
    );
    _items[result.id] = result;
    notifyListeners();
    return result;
  }

  bool save(String id) {
    final item = _items[id];
    if (item == null || item.isSaved) return false;
    _items[id] = item.copyWith(isSaved: true);
    notifyListeners();
    return true;
  }

  void rename(String id, String title) {
    final item = _items[id];
    if (item == null || !item.isSaved || title.trim().isEmpty) {
      throw ArgumentError(
        'A saved itinerary and non-empty title are required.',
      );
    }
    _items[id] = item.copyWith(title: title.trim());
    notifyListeners();
  }

  void delete(String id) {
    if (_items.remove(id) != null) notifyListeners();
  }

  void clear() {
    _items.clear();
    draftPlan = null;
    notifyListeners();
  }
}
