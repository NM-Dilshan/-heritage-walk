/// Packaged images available to every installed copy of HeritageWalk.
class PlaceImageOption {
  const PlaceImageOption(this.displayName, this.assetPath, this.placeNames);
  final String displayName, assetPath;
  final List<String> placeNames;
}

abstract final class PlaceImageCatalog {
  static const options = <PlaceImageOption>[
    PlaceImageOption(
      'Sigiriya Rock Fortress',
      'assets/places/sigiriya_rock_fortress.jpg',
      ['Sigiriya Rock Fortress, Sigiriya', 'Sigiriya Rock Fortress'],
    ),
    PlaceImageOption(
      'Quadrangle, Polonnaruwa',
      'assets/places/quadrangle_polonnaruwa.jpg',
      ['Quadrangle, Polonnaruwa'],
    ),
    PlaceImageOption(
      'Galle Fort and Old Town',
      'assets/places/galle_fort_and_old_town.jpg',
      [
        'Galle Fort and Old Town, Galle',
        'Galle Fort and Old Town',
        'Galle Fort',
      ],
    ),
    PlaceImageOption('Adam’s Peak', 'assets/places/adams_peak.jpg', [
      'Adam’s Peak',
      "Adam's Peak",
    ]),
    PlaceImageOption(
      'Cave Temples, Dambulla',
      'assets/places/cave_temples_dambulla.jpg',
      ['Cave Temples, Dambulla', 'Dambulla Cave Temple'],
    ),
    PlaceImageOption(
      'Abhayagiri Dagoba, Anuradhapura',
      'assets/places/abhayagiri_dagoba_anuradhapura.jpg',
      ['Abhayagiri Dagoba, Anuradhapura'],
    ),
    PlaceImageOption(
      'Nine Arch Bridge, Ella',
      'assets/places/nine_arch_bridge_ella.jpg',
      ['Nine Arch Bridge, Ella', 'Nine Arch Bridge'],
    ),
    PlaceImageOption(
      'Gal Vihara Buddha Figures, Polonnaruwa',
      'assets/places/gal_vihara_buddha_figures_polonnaruwa.jpg',
      ['Gal Vihara Buddha Figures, Polonnaruwa'],
    ),
    PlaceImageOption(
      'Temple of the Tooth, Kandy',
      'assets/places/temple_of_the_tooth_kandy.jpg',
      ['Temple of the Tooth, Kandy', 'Temple of the Tooth'],
    ),
    PlaceImageOption(
      'World’s End, Horton Plains',
      'assets/places/worlds_end_horton_plains.jpg',
      ['World’s End, Horton Plains', "World's End, Horton Plains"],
    ),
    PlaceImageOption(
      'Kandasamy Kovil, Trincomalee',
      'assets/places/kandasamy_kovil_trincomalee.jpg',
      ['Kandasamy Kovil, Trincomalee'],
    ),
    PlaceImageOption(
      'Mulkirigala Rock Temples, Tangalle',
      'assets/places/mulkirigala_rock_temples_tangalle.jpg',
      ['Mulkirigala Rock Temples, Tangalle'],
    ),
    PlaceImageOption(
      'Lipton’s Seat, Haputale',
      'assets/places/liptons_seat_haputale.jpg',
      ['Lipton’s Seat, Haputale', "Lipton's Seat, Haputale"],
    ),
    PlaceImageOption(
      'Kiri Vihara Dagoba, Polonnaruwa',
      'assets/places/kiri_vihara_dagoba_polonnaruwa.jpg',
      ['Kiri Vihara Dagoba, Polonnaruwa'],
    ),
    PlaceImageOption(
      'Jaffna Fort, Jaffna',
      'assets/places/jaffna_fort_jaffna.jpg',
      ['Jaffna Fort, Jaffna', 'Jaffna Fort'],
    ),
    PlaceImageOption(
      'Mihintale Peak and Ruins, Anuradhapura',
      'assets/places/mihintale_peak_and_ruins_anuradhapura.jpg',
      ['Mihintale Peak and Ruins, Anuradhapura'],
    ),
    PlaceImageOption(
      'Japanese Peace Pagoda, Unawatuna',
      'assets/places/japanese_peace_pagoda_unawatuna.jpg',
      ['Japanese Peace Pagoda, Unawatuna'],
    ),
  ];
  static PlaceImageOption? forAsset(String path) =>
      options.where((option) => option.assetPath == path).firstOrNull;

  /// Explicit lookup only; never rewrites data or runs a startup migration.
  static PlaceImageOption? forPlaceName(String name) => options
      .where(
        (option) => option.placeNames.any(
          (alias) => alias.toLowerCase() == name.trim().toLowerCase(),
        ),
      )
      .firstOrNull;
}

abstract final class PlaceImageReferences {
  static bool isAsset(String value) =>
      value.startsWith('assets/') && !value.contains('..');
  static bool isRemote(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }
}
