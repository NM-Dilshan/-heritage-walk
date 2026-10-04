import 'package:flutter/foundation.dart';

import '../models/heritage_place.dart';

class FavoritesService extends ChangeNotifier {
  final Map<String, HeritagePlace> _favorites = {};
  List<HeritagePlace> getFavorites() => List.unmodifiable(_favorites.values);
  bool isFavorite(String id) => _favorites.containsKey(id);
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
