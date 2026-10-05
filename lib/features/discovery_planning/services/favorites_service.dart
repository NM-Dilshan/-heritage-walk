import 'package:flutter/foundation.dart';

import '../models/heritage_place.dart';
import '../../../core/constants/app_assets.dart';

class FavoritesService extends ChangeNotifier {
  final Map<String, HeritagePlace> _favorites = {};
  List<HeritagePlace> getFavorites() => List.unmodifiable(_favorites.values);
  bool isFavorite(String id) => _favorites.containsKey(id);
  void restoreIds(Iterable<String> ids, Iterable<HeritagePlace> catalog) {
    final resolved = {for (final place in catalog) place.id: place};
    restore(
      ids.map(
        (id) =>
            resolved[id] ??
            HeritagePlace(
              id: id,
              name: 'Unavailable place',
              city: '',
              district: '',
              category: '',
              shortDescription:
                  'This place is no longer available in the active catalog.',
              description: 'Your saved favorite is retained. You may remove it at any time.',
              imagePath: AppAssets.placePlaceholder,
              rating: 0,
              reviewCount: 0,
              isActive: false,
            ),
      ),
    );
  }

  void reconcile(Iterable<HeritagePlace> catalog) =>
      restoreIds(_favorites.keys.toList(), catalog);
  void restore(Iterable<HeritagePlace> places) {
    _favorites.clear();
    for (final place in places) {
      _favorites[place.id] = place;
    }
    notifyListeners();
  }

  void addFavorite(HeritagePlace place) {
    if (_favorites.containsKey(place.id)) return;
    _favorites[place.id] = place;
    notifyListeners();
  }

  void removeFavorite(String id) {
    if (_favorites.remove(id) != null) notifyListeners();
  }

  void toggleFavorite(HeritagePlace place) =>
      isFavorite(place.id) ? removeFavorite(place.id) : addFavorite(place);
  void clear() {
    _favorites.clear();
    notifyListeners();
  }
}
