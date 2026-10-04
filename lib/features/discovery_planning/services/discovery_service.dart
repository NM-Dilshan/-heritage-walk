import 'package:flutter/foundation.dart';

import '../../../core/constants/app_assets.dart';
import '../models/heritage_place.dart';

class DiscoveryService extends ChangeNotifier {
  static const categories = [
    'All',
    'Ancient Cities',
    'Temples',
    'Forts',
    'Nature',
    'Architecture',
  ];
  static const destinations = [
    'Kandy',
    'Galle',
    'Sigiriya',
    'Dambulla',
    'Anuradhapura',
    'Polonnaruwa',
    'Jaffna',
    'Ella',
  ];
  String _query = '';
  String _category = 'All';
  String get query => _query;
  String get category => _category;
  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void setCategory(String value) {
    _category = value;
    notifyListeners();
  }

  List<HeritagePlace> get filteredPlaces =>
      search(query: _query, category: _category);
  List<HeritagePlace> search({String query = '', String category = 'All'}) {
    final term = query.trim().toLowerCase();
    return places
        .where(
          (place) =>
              (category == 'All' || place.category == category) &&
              '${place.name} ${place.city} ${place.district} ${place.category}'
                  .toLowerCase()
                  .contains(term),
        )
        .toList();
  }

  // Short neutral descriptions; source links are recorded in Part 3 documentation.
  // Ratings/review counts are illustrative demo values, not public reviews.
  final List<HeritagePlace> places = List.unmodifiable([
    _place(
      'sigiriya',
      'Sigiriya Rock Fortress',
      'Sigiriya',
      'Matale',
      'Forts',
      'A historic rock fortress with gardens and archaeological remains.',
      true,
      4.8,
      124,
    ),
    _place(
      'tooth-temple',
      'Temple of the Sacred Tooth Relic',
      'Kandy',
      'Kandy',
      'Temples',
      'A Buddhist temple in Kandy associated with the sacred tooth relic.',
      true,
      4.7,
      98,
    ),
    _place(
      'galle-fort',
      'Galle Fort',
      'Galle',
      'Galle',
      'Forts',
      'A fortified coastal town with historic streets and buildings.',
      true,
      4.8,
      112,
    ),
    _place(
      'dambulla',
      'Dambulla Cave Temple',
      'Dambulla',
      'Matale',
      'Temples',
      'A Buddhist cave-temple complex with murals and statues.',
      false,
      4.7,
      76,
    ),
    _place(
      'polonnaruwa',
      'Polonnaruwa Ancient City',
      'Polonnaruwa',
      'Polonnaruwa',
      'Ancient Cities',
      'Archaeological remains of a former capital of Sri Lanka.',
      false,
      4.6,
      61,
    ),
    _place(
      'anuradhapura',
      'Anuradhapura Sacred City',
      'Anuradhapura',
      'Anuradhapura',
      'Ancient Cities',
      'A historic sacred city with Buddhist monuments and ancient remains.',
      false,
      4.7,
      83,
    ),
    _place(
      'nine-arch',
      'Nine Arch Bridge',
      'Ella',
      'Badulla',
      'Architecture',
      'A nine-arched railway bridge in the hill country near Ella.',
      false,
      4.6,
      54,
    ),
    _place(
      'jaffna-fort',
      'Jaffna Fort',
      'Jaffna',
      'Jaffna',
      'Forts',
      'A historic fort in the city of Jaffna.',
      false,
      4.5,
      39,
    ),
  ]);
  static HeritagePlace _place(
    String id,
    String name,
    String city,
    String district,
    String category,
    String description,
    bool featured,
    double rating,
    int reviews,
  ) => HeritagePlace(
    id: id,
    name: name,
    city: city,
    district: district,
    category: category,
    shortDescription: description,
    description: description,
    imagePath: AppAssets.placePlaceholder,
    rating: rating,
    reviewCount: reviews,
    isFeatured: featured,
  );
}
